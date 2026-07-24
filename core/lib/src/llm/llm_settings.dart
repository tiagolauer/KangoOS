import 'llm_provider.dart';
import 'providers/anthropic_provider.dart';
import 'providers/ollama_provider.dart';
import 'providers/openai_provider.dart';

enum LlmProviderKind { ollama, anthropic, openAi }

class LlmSettings {
  const LlmSettings({
    required this.provider,
    this.model = '',
    this.apiKey = '',
    this.baseUrl = '',
  });

  static const defaults = LlmSettings(
    provider: LlmProviderKind.ollama,
    model: 'llama3',
  );

  final LlmProviderKind provider;
  final String model;
  final String apiKey;
  final String baseUrl;

  LlmSettings copyWith({
    LlmProviderKind? provider,
    String? model,
    String? apiKey,
    String? baseUrl,
  }) {
    return LlmSettings(
      provider: provider ?? this.provider,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
    );
  }

  LlmProvider buildProvider() {
    switch (provider) {
      case LlmProviderKind.ollama:
        return OllamaProvider(
          model: model,
          baseUrl: baseUrl.isEmpty ? 'http://localhost:11434' : baseUrl,
        );
      case LlmProviderKind.anthropic:
        return AnthropicProvider(apiKey: apiKey, model: model);
      case LlmProviderKind.openAi:
        return OpenAiProvider(apiKey: apiKey, model: model);
    }
  }
}
