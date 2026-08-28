import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_http.dart';
import '../llm_provider.dart';

class OllamaProvider extends LlmProvider {
  OllamaProvider({
    required this.model,
    this.baseUrl = 'http://localhost:11434',
    this.timeout = defaultLlmTimeout,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String model;
  final String baseUrl;
  final Duration timeout;
  final http.Client _client;

  @override
  String get id => 'ollama';

  @override
  bool get supportsToolCalls => true;

  @override
  Stream<String> chat(List<LlmMessage> messages) async* {
    final request =
        http.Request('POST', Uri.parse('$baseUrl/api/chat'))
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode({
            'model': model,
            'stream': true,
            'messages':
                messages
                    .map((m) => {'role': m.role.name, 'content': m.content})
                    .toList(),
          });

    final response = await sendLlmRequest(
      client: _client,
      request: request,
      provider: id,
      timeout: timeout,
    );
    final lines = response.stream
        .timeout(timeout)
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lines) {
      if (line.isEmpty) continue;
      final json = jsonDecode(line) as Map<String, dynamic>;
      final content =
          (json['message'] as Map<String, dynamic>?)?['content'] as String?;
      if (content != null && content.isNotEmpty) yield content;
      if (json['done'] == true) break;
    }
  }

  @override
  Future<LlmResponse> complete(
    List<LlmMessage> messages, {
    List<LlmToolDefinition> tools = const [],
  }) async {
    final request =
        http.Request('POST', Uri.parse('$baseUrl/api/chat'))
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode({
            'model': model,
            'stream': false,
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
    final message = (body['message'] as Map).cast<String, dynamic>();
    final calls = <LlmToolCall>[];
    for (
      var index = 0;
      index < (message['tool_calls'] as List? ?? const []).length;
      index++
    ) {
      final raw = (message['tool_calls'] as List)[index];
      final call = (raw as Map).cast<String, dynamic>();
      final function = (call['function'] as Map).cast<String, dynamic>();
      calls.add(
        LlmToolCall(
          id: call['id'] as String? ?? 'ollama-$index',
          name: function['name'] as String,
          arguments: _arguments(function['arguments']),
        ),
      );
    }
    return LlmResponse(
      content: message['content'] as String? ?? '',
      toolCalls: calls,
      stopReason:
          calls.isEmpty ? LlmStopReason.completed : LlmStopReason.toolCalls,
    );
  }

  static Map<String, Object?> _messageJson(LlmMessage message) => {
    'role': message.role.name,
    'content': message.content,
    if (message.toolCallId != null) 'tool_call_id': message.toolCallId,
    if (message.name != null) 'tool_name': message.name,
    if (message.toolCalls.isNotEmpty)
      'tool_calls': [
        for (final call in message.toolCalls)
          {
            'id': call.id,
            'function': {'name': call.name, 'arguments': call.arguments},
          },
      ],
  };

  static Map<String, Object?> _arguments(Object? raw) {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map) return const {};
    return decoded.cast<String, Object?>();
  }
}
