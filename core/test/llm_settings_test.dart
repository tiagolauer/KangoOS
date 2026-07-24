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
  });

  test('ollama defaults to localhost when baseUrl is empty', () {
    final provider = const LlmSettings(provider: LlmProviderKind.ollama, model: 'llama3')
        .buildProvider() as OllamaProvider;
    expect(provider.baseUrl, 'http://localhost:11434');
  });
}
