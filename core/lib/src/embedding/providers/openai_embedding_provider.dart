import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../llm/llm_http.dart';
import '../embedding_provider.dart';

class OpenAiEmbeddingProvider implements EmbeddingProvider {
  OpenAiEmbeddingProvider({
    required this.model,
    required this.baseUrl,
    this.apiKey = '',
    this.timeout = defaultLlmTimeout,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String model;
  final String baseUrl;
  final String apiKey;
  final Duration timeout;
  final http.Client _client;

  @override
  String get id => 'openai-compatible:$baseUrl:$model';

  @override
  Future<List<double>> embed(String text) async {
    final endpoint = '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/embeddings';
    final request = http.Request('POST', Uri.parse(endpoint))
      ..headers.addAll({
        'Content-Type': 'application/json',
        if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
      })
      ..body = jsonEncode({'model': model, 'input': text});
    final response = await sendLlmRequest(
      client: _client,
      request: request,
      provider: id,
      timeout: timeout,
    );
    final body = await response.stream.bytesToString().timeout(timeout);
    final json = jsonDecode(body) as Map<String, dynamic>;
    final data = json['data'] as List?;
    final embedding = data?.firstOrNull?['embedding'] as List?;
    if (embedding == null) {
      throw const FormatException('Embedding response is missing data.');
    }
    return embedding.cast<num>().map((value) => value.toDouble()).toList();
  }
}
