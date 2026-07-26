import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_http.dart';
import '../llm_provider.dart';
import '../sse.dart';

class GeminiProvider implements LlmProvider {
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
  Stream<String> chat(List<LlmMessage> messages) async* {
    final system = messages
        .where((m) => m.role == LlmRole.system)
        .map((m) => m.content)
        .join('\n');
    final conversation = messages.where((m) => m.role != LlmRole.system);

    final uri = Uri.parse('$_baseUrl/$model:streamGenerateContent?alt=sse');
    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['x-goog-api-key'] = apiKey
      ..body = jsonEncode({
        if (system.isNotEmpty)
          'systemInstruction': {
            'parts': [
              {'text': system}
            ],
          },
        'contents': conversation
            .map((m) => {
                  'role': m.role == LlmRole.user ? 'user' : 'model',
                  'parts': [
                    {'text': m.content}
                  ],
                })
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
      final parts = (candidates.first['content']
          as Map<String, dynamic>?)?['parts'] as List?;
      if (parts == null) continue;
      for (final part in parts) {
        final text = (part as Map<String, dynamic>)['text'] as String?;
        if (text != null && text.isNotEmpty) yield text;
      }
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
