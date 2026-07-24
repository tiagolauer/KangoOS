import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_provider.dart';
import '../sse.dart';

class AnthropicProvider implements LlmProvider {
  AnthropicProvider({
    required this.apiKey,
    required this.model,
    this.maxTokens = 4096,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final int maxTokens;
  final http.Client _client;

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _apiVersion = '2023-06-01';

  @override
  String get id => 'anthropic';

  @override
  Stream<String> chat(List<LlmMessage> messages) async* {
    final system = messages
        .where((m) => m.role == LlmRole.system)
        .map((m) => m.content)
        .join('\n');
    final conversation = messages.where((m) => m.role != LlmRole.system);

    final request = http.Request('POST', Uri.parse(_endpoint))
      ..headers.addAll({
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': _apiVersion,
      })
      ..body = jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'stream': true,
        if (system.isNotEmpty) 'system': system,
        'messages': conversation
            .map((m) => {
                  'role': m.role == LlmRole.user ? 'user' : 'assistant',
                  'content': m.content,
                })
            .toList(),
      });

    final response = await _client.send(request);
    await for (final data in sseDataLines(response.stream)) {
      final event = jsonDecode(data) as Map<String, dynamic>;
      if (event['type'] != 'content_block_delta') continue;
      final delta = event['delta'] as Map<String, dynamic>;
      if (delta['type'] != 'text_delta') continue;
      yield delta['text'] as String;
    }
  }
}
