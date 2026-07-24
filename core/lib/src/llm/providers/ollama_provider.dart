import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_provider.dart';

class OllamaProvider implements LlmProvider {
  OllamaProvider({
    required this.model,
    this.baseUrl = 'http://localhost:11434',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String model;
  final String baseUrl;
  final http.Client _client;

  @override
  String get id => 'ollama';

  @override
  Stream<String> chat(List<LlmMessage> messages) async* {
    final request = http.Request('POST', Uri.parse('$baseUrl/api/chat'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'model': model,
        'stream': true,
        'messages': messages
            .map((m) => {'role': m.role.name, 'content': m.content})
            .toList(),
      });

    final response = await _client.send(request);
    final lines =
        response.stream.transform(utf8.decoder).transform(const LineSplitter());

    await for (final line in lines) {
      if (line.isEmpty) continue;
      final json = jsonDecode(line) as Map<String, dynamic>;
      final content =
          (json['message'] as Map<String, dynamic>?)?['content'] as String?;
      if (content != null && content.isNotEmpty) yield content;
      if (json['done'] == true) break;
    }
  }
}
