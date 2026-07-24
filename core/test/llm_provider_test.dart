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
}
