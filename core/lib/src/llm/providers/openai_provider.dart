import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_http.dart';
import '../llm_provider.dart';
import '../sse.dart';

const defaultOpenAiBaseUrl = 'https://api.openai.com/v1';

class OpenAiProvider extends LlmProvider {
  OpenAiProvider({
    required this.apiKey,
    required this.model,
    this.baseUrl = defaultOpenAiBaseUrl,
    this.reasoningEffort = ReasoningEffort.balanced,
    this.timeout = defaultLlmTimeout,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final String baseUrl;
  final ReasoningEffort reasoningEffort;
  final Duration timeout;
  final http.Client _client;

  @override
  String get id => 'openai';

  @override
  bool get supportsToolCalls => true;

  @override
  Stream<String> chat(List<LlmMessage> messages) async* {
    final endpoint =
        '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/chat/completions';
    final request =
        http.Request('POST', Uri.parse(endpoint))
          ..headers.addAll({
            'Content-Type': 'application/json',
            if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
          })
          ..body = jsonEncode({
            'model': model,
            'stream': true,
            // Only reasoning-capable models (o-series/gpt-5 family) accept this;
            // other models reject unknown params, so 'balanced' omits it entirely
            // rather than defaulting to 'medium'.
            if (_effortName(reasoningEffort) case final effort?)
              'reasoning_effort': effort,
            'messages': messages.map(_messageJson).toList(),
          });

    final response = await sendLlmRequest(
      client: _client,
      request: request,
      provider: id,
      timeout: timeout,
    );
    await for (final data in sseDataLines(response.stream.timeout(timeout))) {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final choices = json['choices'] as List;
      final delta = choices.first['delta'] as Map<String, dynamic>;
      final content = delta['content'] as String?;
      if (content != null && content.isNotEmpty) yield content;
    }
  }

  @override
  Future<LlmResponse> complete(
    List<LlmMessage> messages, {
    List<LlmToolDefinition> tools = const [],
  }) async {
    final endpoint =
        '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/chat/completions';
    final request =
        http.Request('POST', Uri.parse(endpoint))
          ..headers.addAll({
            'Content-Type': 'application/json',
            if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
          })
          ..body = jsonEncode({
            'model': model,
            'stream': false,
            if (_effortName(reasoningEffort) case final effort?)
              'reasoning_effort': effort,
            'messages': messages.map(_messageJson).toList(),
            if (tools.isNotEmpty)
              'tools': [
                for (final tool in tools)
                  {
                    'type': 'function',
                    'function': {
                      'name': tool.name,
                      'description': tool.description,
                      'parameters': tool.inputSchema,
                    },
                  },
              ],
          });
    final response = await sendLlmRequest(
      client: _client,
      request: request,
      provider: id,
      timeout: timeout,
    );
    final body =
        jsonDecode(await response.stream.bytesToString().timeout(timeout))
            as Map<String, dynamic>;
    final choices = body['choices'] as List? ?? const [];
    if (choices.isEmpty) throw const FormatException('Missing LLM choice.');
    final choice = (choices.first as Map).cast<String, dynamic>();
    final message = (choice['message'] as Map).cast<String, dynamic>();
    final calls = <LlmToolCall>[];
    for (final raw in message['tool_calls'] as List? ?? const []) {
      final call = (raw as Map).cast<String, dynamic>();
      final function = (call['function'] as Map).cast<String, dynamic>();
      calls.add(
        LlmToolCall(
          id: call['id'] as String,
          name: function['name'] as String,
          arguments: _arguments(function['arguments']),
        ),
      );
    }
    return LlmResponse(
      content: message['content'] as String? ?? '',
      toolCalls: calls,
      stopReason: _stopReason(choice['finish_reason'] as String?, calls),
    );
  }

  static Map<String, Object?> _messageJson(LlmMessage message) => {
    'role': message.role.name,
    'content': message.content,
    if (message.toolCallId != null) 'tool_call_id': message.toolCallId,
    if (message.name != null) 'name': message.name,
    if (message.toolCalls.isNotEmpty)
      'tool_calls': [
        for (final call in message.toolCalls)
          {
            'id': call.id,
            'type': 'function',
            'function': {
              'name': call.name,
              'arguments': jsonEncode(call.arguments),
            },
          },
      ],
  };

  static Map<String, Object?> _arguments(Object? raw) {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map) return const {};
    return decoded.cast<String, Object?>();
  }

  static LlmStopReason _stopReason(String? reason, List<LlmToolCall> calls) {
    if (calls.isNotEmpty || reason == 'tool_calls') {
      return LlmStopReason.toolCalls;
    }
    if (reason == 'length') return LlmStopReason.length;
    if (reason == null || reason == 'stop') return LlmStopReason.completed;
    return LlmStopReason.other;
  }

  static String? _effortName(ReasoningEffort effort) {
    switch (effort) {
      case ReasoningEffort.fast:
        return 'low';
      case ReasoningEffort.balanced:
        return null;
      case ReasoningEffort.thinking:
        return 'high';
    }
  }
}
