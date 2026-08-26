import 'package:kangoos_core/kangoos_core.dart';
import 'package:test/test.dart';

void main() {
  test('buildProvider maps each provider kind to the matching provider', () {
    final ollama = const LlmSettings(
      provider: LlmProviderKind.ollama,
      model: 'llama3',
    ).buildProvider();
    expect(ollama, isA<OllamaProvider>());
    expect(ollama.id, 'ollama');

    final anthropic = const LlmSettings(
      provider: LlmProviderKind.anthropic,
      model: 'claude-opus-4-8',
      apiKey: 'key',
    ).buildProvider();
    expect(anthropic, isA<AnthropicProvider>());
    expect(anthropic.id, 'anthropic');

    final openAi = const LlmSettings(
      provider: LlmProviderKind.openAi,
      model: 'gpt-4o',
      apiKey: 'key',
    ).buildProvider();
    expect(openAi, isA<OpenAiProvider>());
    expect(openAi.id, 'openai');

    final gemini = const LlmSettings(
      provider: LlmProviderKind.gemini,
      model: 'gemini-2.5-flash',
      apiKey: 'key',
    ).buildProvider();
    expect(gemini, isA<GeminiProvider>());
    expect(gemini.id, 'gemini');
  });

  test('reasoningEffort flows from settings into the built provider', () {
    final anthropic = const LlmSettings(
      provider: LlmProviderKind.anthropic,
      model: 'claude-opus-4-8',
      apiKey: 'key',
      reasoningEffort: ReasoningEffort.thinking,
    ).buildProvider() as AnthropicProvider;
    expect(anthropic.reasoningEffort, ReasoningEffort.thinking);
  });

  test('ollama defaults to localhost when baseUrl is empty', () {
    final provider =
        const LlmSettings(provider: LlmProviderKind.ollama, model: 'llama3')
            .buildProvider() as OllamaProvider;
    expect(provider.baseUrl, 'http://localhost:11434');
  });

  test('loopback OpenAI-compatible settings build LM Studio providers', () {
    const settings = LlmSettings(
      provider: LlmProviderKind.openAi,
      model: 'qwen/qwen3-8b',
      baseUrl: 'http://127.0.0.1:1234/v1',
      embeddingModel: 'text-embedding-nomic-embed-text-v1.5',
    );

    final chat = settings.buildProvider() as OpenAiProvider;
    final embedding =
        settings.buildEmbeddingProvider() as OpenAiEmbeddingProvider;

    expect(settings.requiresApiKey, isFalse);
    expect(settings.isLocalEndpoint, isTrue);
    expect(chat.baseUrl, 'http://127.0.0.1:1234/v1');
    expect(embedding.baseUrl, 'http://127.0.0.1:1234/v1');
  });
}
