import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_http.dart';
import '../llm_provider.dart';
import '../sse.dart';

class GeminiProvider extends LlmProvider {
  GeminiProvider({
    required this.apiKey,
    required this.model,
    this.reasoningEffort = ReasoningEffort.balanced,
    this.timeout = defaultLlmTimeout,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final ReasoningEffort reasoningEffort;
  final Duration timeout;
  final http.Client _client;

  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  @override
  String get id => 'gemini';

  @override
  bool get supportsToolCalls => true;

  @override
  Stream<String> chat(List<LlmMessage> messages) async* {
    final system = messages
        .where((m) => m.role == LlmRole.system)
        .map((m) => m.content)
        .join('\n');
    final conversation = messages.where((m) => m.role != LlmRole.system);

    final uri = Uri.parse('$_baseUrl/$model:streamGenerateContent?alt=sse');
    final request =
        http.Request('POST', uri)
          ..headers['Content-Type'] = 'application/json'
          ..headers['x-goog-api-key'] = apiKey
          ..body = jsonEncode({
            if (system.isNotEmpty)
              'systemInstruction': {
                'parts': [
                  {'text': system},
                ],
              },
            'contents':
                conversation
                    .map(
                      (m) => {
                        'role': m.role == LlmRole.user ? 'user' : 'model',
                        'parts': [
                          {'text': m.content},
                        ],
                      },
                    )
                    .toList(),
            if (_thinkingBudget(reasoningEffort) case final budget?)
              'generationConfig': {
                'thinkingConfig': {'thinkingBudget': budget},
              },
          });

    final response = await sendLlmRequest(
      client: _client,
      request: request,
      provider: id,
      timeout: timeout,
    );
    await for (final data in sseDataLines(response.stream.timeout(timeout))) {
      final event = jsonDecode(data) as Map<String, dynamic>;
      final candidates = event['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) continue;
      final parts =
          (candidates.first['content'] as Map<String, dynamic>?)?['parts']
              as List?;
      if (parts == null) continue;
      for (final part in parts) {
        final text = (part as Map<String, dynamic>)['text'] as String?;
        if (text != null && text.isNotEmpty) yield text;
      }
    }
  }

  @override
  Future<LlmResponse> complete(
    List<LlmMessage> messages, {
    List<LlmToolDefinition> tools = const [],
  }) async {
    final system = messages
        .where((message) => message.role == LlmRole.system)
        .map((message) => message.content)
        .join('\n');
    final request =
        http.Request('POST', Uri.parse('$_baseUrl/$model:generateContent'))
          ..headers['Content-Type'] = 'application/json'
          ..headers['x-goog-api-key'] = apiKey
          ..body = jsonEncode({
            if (system.isNotEmpty)
              'systemInstruction': {
                'parts': [
                  {'text': system},
                ],
              },
            'contents':
                messages
                    .where((message) => message.role != LlmRole.system)
                    .map(_structuredMessage)
                    .toList(),
            if (tools.isNotEmpty)
              'tools': [
                {
                  'functionDeclarations': [
                    for (final tool in tools)
                      {
                        'name': tool.name,
                        'description': tool.description,
                        'parameters': tool.inputSchema,
                      },
                  ],
                },
              ],
            if (_thinkingBudget(reasoningEffort) case final budget?)
              'generationConfig': {
                'thinkingConfig': {'thinkingBudget': budget},
              },
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
    final candidates = body['candidates'] as List? ?? const [];
    if (candidates.isEmpty) {
      throw const FormatException('Missing Gemini candidate.');
    }
    final candidate = (candidates.first as Map).cast<String, dynamic>();
    final content = (candidate['content'] as Map?)?.cast<String, dynamic>();
    final parts = content?['parts'] as List? ?? const [];
    final text = StringBuffer();
    final calls = <LlmToolCall>[];
    for (var index = 0; index < parts.length; index++) {
      final part = (parts[index] as Map).cast<String, dynamic>();
      final value = part['text'] as String?;
      if (value != null) text.write(value);
      final function = (part['functionCall'] as Map?)?.cast<String, dynamic>();
      if (function != null) {
        final name = function['name'] as String;
        calls.add(
          LlmToolCall(
            id: 'gemini-$index-$name',
            name: name,
            arguments:
                (function['args'] as Map?)?.cast<String, Object?>() ?? const {},
          ),
        );
      }
    }
    final reason = candidate['finishReason'] as String?;
    return LlmResponse(
      content: text.toString(),
      toolCalls: calls,
      stopReason:
          calls.isNotEmpty
              ? LlmStopReason.toolCalls
              : reason == 'MAX_TOKENS'
              ? LlmStopReason.length
              : reason == null || reason == 'STOP'
              ? LlmStopReason.completed
              : LlmStopReason.other,
    );
  }

  static Map<String, Object?> _structuredMessage(LlmMessage message) {
    if (message.role == LlmRole.tool) {
      return {
        'role': 'user',
        'parts': [
          {
            'functionResponse': {
              'name': message.name,
              'response': _toolResponse(message.content),
            },
          },
        ],
      };
    }
    return {
      'role': message.role == LlmRole.user ? 'user' : 'model',
      'parts': [
        if (message.content.isNotEmpty) {'text': message.content},
        for (final call in message.toolCalls)
          {
            'functionCall': {'name': call.name, 'args': call.arguments},
          },
      ],
    };
  }

  static Map<String, Object?> _toolResponse(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) return decoded.cast<String, Object?>();
      return {'result': decoded};
    } on FormatException {
      return {'result': content};
    }
  }

  /// Null omits `thinkingConfig` entirely (model default) — the safest
  /// choice for `balanced`, since older Gemini models don't support it.
  static int? _thinkingBudget(ReasoningEffort effort) {
    switch (effort) {
      case ReasoningEffort.fast:
        return 0;
      case ReasoningEffort.balanced:
        return null;
      case ReasoningEffort.thinking:
        return -1;
    }
  }
}
