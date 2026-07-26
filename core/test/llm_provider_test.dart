import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:test/test.dart';

void main() {
  const userMessages = [LlmMessage(role: LlmRole.user, content: 'hi')];

  test('OllamaProvider streams message content from NDJSON lines', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'http://localhost:11434/api/chat');
      return http.Response(
        '{"message":{"role":"assistant","content":"Hel"},"done":false}\n'
        '{"message":{"role":"assistant","content":"lo"},"done":false}\n'
        '{"message":{"role":"assistant","content":""},"done":true}\n',
        200,
      );
    });

    final provider = OllamaProvider(model: 'llama3', client: client);
    final chunks = await provider.chat(userMessages).toList();

    expect(chunks.join(), 'Hello');
  });

  test('AnthropicProvider streams text from content_block_delta SSE events',
      () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(request.headers['x-api-key'], 'test-key');
      expect(request.headers['anthropic-version'], '2023-06-01');
      return http.Response(
        'event: message_start\n'
        'data: {"type":"message_start"}\n\n'
        'event: content_block_delta\n'
        'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hel"}}\n\n'
        'event: content_block_delta\n'
        'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"lo"}}\n\n'
        'event: message_stop\n'
        'data: {"type":"message_stop"}\n\n',
        200,
      );
    });

    final provider = AnthropicProvider(
      apiKey: 'test-key',
      model: 'claude-opus-4-8',
      client: client,
    );
    final chunks = await provider.chat(userMessages).toList();

    expect(chunks.join(), 'Hello');
  });

  test('OpenAiProvider streams delta content and stops at [DONE]', () async {
    final client = MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer test-key');
      return http.Response(
        'data: {"choices":[{"delta":{"content":"Hel"}}]}\n\n'
        'data: {"choices":[{"delta":{"content":"lo"}}]}\n\n'
        'data: [DONE]\n\n',
        200,
      );
    });

    final provider = OpenAiProvider(
      apiKey: 'test-key',
      model: 'gpt-4o',
      client: client,
    );
    final chunks = await provider.chat(userMessages).toList();

    expect(chunks.join(), 'Hello');
  });

  test(
      'OpenAiProvider omits reasoning_effort for balanced but sends it for fast/thinking',
      () async {
    Map<String, dynamic>? lastBody;
    final client = MockClient((request) async {
      lastBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('data: [DONE]\n\n', 200);
    });

    await OpenAiProvider(apiKey: 'k', model: 'gpt-5', client: client)
        .chat(userMessages)
        .drain<void>();
    expect(lastBody!.containsKey('reasoning_effort'), isFalse);

    await OpenAiProvider(
      apiKey: 'k',
      model: 'gpt-5',
      reasoningEffort: ReasoningEffort.thinking,
      client: client,
    ).chat(userMessages).drain<void>();
    expect(lastBody!['reasoning_effort'], 'high');
  });

  test('AnthropicProvider enables extended thinking only for the thinking mode',
      () async {
    Map<String, dynamic>? lastBody;
    final client = MockClient((request) async {
      lastBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response('data: {"type":"message_stop"}\n\n', 200);
    });

    await AnthropicProvider(
            apiKey: 'k', model: 'claude-opus-4-8', client: client)
        .chat(userMessages)
        .drain<void>();
    expect(lastBody!.containsKey('thinking'), isFalse);
    expect(lastBody!['max_tokens'], 4096);

    await AnthropicProvider(
      apiKey: 'k',
      model: 'claude-opus-4-8',
      reasoningEffort: ReasoningEffort.thinking,
      client: client,
    ).chat(userMessages).drain<void>();
    expect(lastBody!['thinking'], {'type': 'enabled', 'budget_tokens': 8000});
    expect(lastBody!['max_tokens'], 4096 + 8000);
  });

  test('GeminiProvider streams text parts and maps system messages separately',
      () async {
    Map<String, dynamic>? lastBody;
    final client = MockClient((request) async {
      expect(request.url.toString(), contains('streamGenerateContent'));
      expect(request.url.toString(), isNot(contains('test-key')));
      expect(request.headers['x-goog-api-key'], 'test-key');
      lastBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        'data: {"candidates":[{"content":{"parts":[{"text":"Hel"}]}}]}\n\n'
        'data: {"candidates":[{"content":{"parts":[{"text":"lo"}]}}]}\n\n',
        200,
      );
    });

    final provider = GeminiProvider(
        apiKey: 'test-key', model: 'gemini-2.5-flash', client: client);
    final chunks = await provider.chat(const [
      LlmMessage(role: LlmRole.system, content: 'be terse'),
      LlmMessage(role: LlmRole.user, content: 'hi'),
    ]).toList();

    expect(chunks.join(), 'Hello');
    expect(lastBody!['systemInstruction'], {
      'parts': [
        {'text': 'be terse'}
      ],
    });
    expect(lastBody!['contents'], [
      {
        'role': 'user',
        'parts': [
          {'text': 'hi'}
        ],
      }
    ]);
  });

  group('HTTP errors surface as LlmException', () {
    final providers = <String, LlmProvider Function(http.Client)>{
      'ollama': (client) => OllamaProvider(model: 'llama3', client: client),
      'anthropic': (client) =>
          AnthropicProvider(apiKey: 'bad', model: 'm', client: client),
      'openai': (client) =>
          OpenAiProvider(apiKey: 'bad', model: 'm', client: client),
      'gemini': (client) =>
          GeminiProvider(apiKey: 'bad', model: 'm', client: client),
    };

    providers.forEach((name, build) {
      test('$name reports a 401 instead of an empty stream', () {
        final client = MockClient((request) async => http.Response(
              '{"error":{"message":"invalid api key"}}',
              401,
            ));

        expect(
          build(client).chat(userMessages).toList(),
          throwsA(isA<LlmException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.message, 'message', 'invalid api key')
              .having((e) => e.provider, 'provider', name)),
        );
      });
    });

    test('a non-JSON error body is passed through as text', () {
      final client =
          MockClient((request) async => http.Response('Bad Gateway', 502));

      expect(
        OllamaProvider(model: 'llama3', client: client)
            .chat(userMessages)
            .toList(),
        throwsA(isA<LlmException>()
            .having((e) => e.message, 'message', 'Bad Gateway')),
      );
    });
  });

  test('a stalled stream times out instead of hanging', () {
    final client = MockClient.streaming((request, bodyStream) async =>
        http.StreamedResponse(StreamController<List<int>>().stream, 200));

    expect(
      OllamaProvider(
        model: 'llama3',
        timeout: const Duration(milliseconds: 50),
        client: client,
      ).chat(userMessages).toList(),
      throwsA(isA<TimeoutException>()),
    );
  });
}
