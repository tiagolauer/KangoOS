import 'llm_provider.dart';
import 'providers/anthropic_provider.dart';
import 'providers/gemini_provider.dart';
import 'providers/ollama_provider.dart';
import 'providers/openai_provider.dart';

enum LlmProviderKind { ollama, anthropic, openAi, gemini }

class LlmSettings {
  const LlmSettings({
    required this.provider,
    this.model = '',
    this.apiKey = '',
    this.baseUrl = '',
    this.reasoningEffort = ReasoningEffort.balanced,
  });

  static const defaults = LlmSettings(
    provider: LlmProviderKind.ollama,
    model: 'llama3',
  );

  final LlmProviderKind provider;
  final String model;
  final String apiKey;
  final String baseUrl;

  /// Ignored by [LlmProviderKind.ollama] — local models have no standardized
  /// reasoning-effort API to target.
  final ReasoningEffort reasoningEffort;

  LlmSettings copyWith({
    LlmProviderKind? provider,
    String? model,
    String? apiKey,
    String? baseUrl,
    ReasoningEffort? reasoningEffort,
  }) {
    return LlmSettings(
      provider: provider ?? this.provider,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
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
        return AnthropicProvider(
          apiKey: apiKey,
          model: model,
          reasoningEffort: reasoningEffort,
        );
      case LlmProviderKind.openAi:
        return OpenAiProvider(
          apiKey: apiKey,
          model: model,
          reasoningEffort: reasoningEffort,
        );
      case LlmProviderKind.gemini:
        return GeminiProvider(
          apiKey: apiKey,
          model: model,
          reasoningEffort: reasoningEffort,
        );
    }
  }
}
