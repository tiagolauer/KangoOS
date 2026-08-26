import '../embedding/embedding_provider.dart';
import '../embedding/providers/ollama_embedding_provider.dart';
import '../embedding/providers/openai_embedding_provider.dart';
import 'llm_provider.dart';
import 'providers/anthropic_provider.dart';
import 'providers/gemini_provider.dart';
import 'providers/ollama_provider.dart';
import 'providers/openai_provider.dart';

enum LlmProviderKind { ollama, anthropic, openAi, gemini }

const defaultOllamaBaseUrl = 'http://localhost:11434';
const defaultEmbeddingModel = 'nomic-embed-text';

class LlmSettings {
  const LlmSettings({
    required this.provider,
    this.model = '',
    this.apiKey = '',
    this.baseUrl = '',
    this.reasoningEffort = ReasoningEffort.balanced,
    this.embeddingModel = defaultEmbeddingModel,
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

  final String embeddingModel;

  String get ollamaBaseUrl => baseUrl.isEmpty ? defaultOllamaBaseUrl : baseUrl;

  String get openAiBaseUrl => baseUrl.isEmpty ? defaultOpenAiBaseUrl : baseUrl;

  bool get isLocalEndpoint {
    final value = switch (provider) {
      LlmProviderKind.ollama => ollamaBaseUrl,
      LlmProviderKind.openAi => openAiBaseUrl,
      _ => '',
    };
    final host = Uri.tryParse(value)?.host.toLowerCase() ?? '';
    return host == 'localhost' ||
        host == '::1' ||
        host == '0:0:0:0:0:0:0:1' ||
        host.startsWith('127.');
  }

  bool get requiresApiKey =>
      provider != LlmProviderKind.ollama && !isLocalEndpoint;

  LlmSettings copyWith({
    LlmProviderKind? provider,
    String? model,
    String? apiKey,
    String? baseUrl,
    ReasoningEffort? reasoningEffort,
    String? embeddingModel,
  }) {
    return LlmSettings(
      provider: provider ?? this.provider,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
      embeddingModel: embeddingModel ?? this.embeddingModel,
    );
  }

  EmbeddingProvider buildEmbeddingProvider() {
    final selectedModel =
        embeddingModel.isEmpty ? defaultEmbeddingModel : embeddingModel;
    if (provider == LlmProviderKind.openAi) {
      return OpenAiEmbeddingProvider(
        model: selectedModel,
        baseUrl: openAiBaseUrl,
        apiKey: apiKey,
      );
    }
    return OllamaEmbeddingProvider(
      model: selectedModel,
      baseUrl: ollamaBaseUrl,
    );
  }

  LlmProvider buildProvider() {
    switch (provider) {
      case LlmProviderKind.ollama:
        return OllamaProvider(model: model, baseUrl: ollamaBaseUrl);
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
          baseUrl: openAiBaseUrl,
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
