import 'dart:convert';

import 'package:http/http.dart' as http;

import '../llm_http.dart';
import '../llm_provider.dart';
import '../sse.dart';

const defaultOpenAiBaseUrl = 'https://api.openai.com/v1';

class OpenAiProvider implements LlmProvider {
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
  Stream<String> chat(List<LlmMessage> messages) async* {
    final endpoint =
        '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/chat/completions';
    final request = http.Request('POST', Uri.parse(endpoint))
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
        'messages': messages
            .map((m) => {'role': m.role.name, 'content': m.content})
            .toList(),
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
