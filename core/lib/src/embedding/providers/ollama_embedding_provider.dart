import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../embedding_provider.dart';

class OllamaEmbeddingProvider implements EmbeddingProvider {
  OllamaEmbeddingProvider({
    required this.model,
    this.baseUrl = 'http://localhost:11434',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String model;
  final String baseUrl;
  final http.Client _client;

  @override
  String get id => 'ollama:$model';

  @override
  Future<List<double>> embed(String text) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/embeddings'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'model': model, 'prompt': text}),
    );
    if (response.statusCode != 200) {
      throw HttpException(
        'Ollama embeddings request failed (${response.statusCode}): ${response.body}',
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final embedding = json['embedding'] as List?;
    if (embedding == null) {
      throw const FormatException(
          'Ollama embeddings response missing "embedding"');
    }
    return embedding.cast<num>().map((n) => n.toDouble()).toList();
  }
}
