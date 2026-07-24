import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_provider.dart';
import '../sse.dart';

class OpenAiProvider implements LlmProvider {
  OpenAiProvider({
    required this.apiKey,
    required this.model,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final http.Client _client;

  static const _endpoint = 'https://api.openai.com/v1/chat/completions';

  @override
  String get id => 'openai';

  @override
  Stream<String> chat(List<LlmMessage> messages) async* {
    final request = http.Request('POST', Uri.parse(_endpoint))
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      })
      ..body = jsonEncode({
        'model': model,
        'stream': true,
        'messages': messages
            .map((m) => {'role': m.role.name, 'content': m.content})
            .toList(),
      });

    final response = await _client.send(request);
    await for (final data in sseDataLines(response.stream)) {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final choices = json['choices'] as List;
      final delta = choices.first['delta'] as Map<String, dynamic>;
      final content = delta['content'] as String?;
      if (content != null && content.isNotEmpty) yield content;
    }
  }
}
