import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';

class EnvConfig {
  const EnvConfig({
    required this.apiToken,
    required this.dbPath,
    required this.llmSettings,
    required this.embeddingModel,
    required this.ollamaBaseUrl,
    required this.port,
    this.databaseEncryptionKey,
  });

  final String apiToken;
  final String dbPath;
  final LlmSettings llmSettings;
  final String embeddingModel;
  final String ollamaBaseUrl;
  final int port;
  final String? databaseEncryptionKey;

  static const minApiTokenLength = 32;

  factory EnvConfig.fromEnvironment(Map<String, String> env) {
    final apiToken = env['KANGOOS_API_TOKEN'];
    if (apiToken == null || apiToken.isEmpty) {
      throw StateError(
        'KANGOOS_API_TOKEN is required. Set it to a random secret and send '
        'the same value as "Authorization: Bearer <token>" from clients.',
      );
    }
    if (apiToken.length < minApiTokenLength) {
      throw StateError(
        'KANGOOS_API_TOKEN is too short: it must be at least '
        '$minApiTokenLength characters. Generate one with '
        '`openssl rand -hex 32`.',
      );
    }

    final providerName =
        env['KANGOOS_LLM_PROVIDER'] ?? LlmProviderKind.ollama.name;
    final provider = LlmProviderKind.values.firstWhere(
      (kind) => kind.name == providerName,
      orElse: () =>
          throw StateError('Unknown KANGOOS_LLM_PROVIDER: $providerName'),
    );

    return EnvConfig(
      apiToken: apiToken,
      dbPath: env['KANGOOS_DB_PATH'] ?? 'kangoos.db',
      llmSettings: LlmSettings(
        provider: provider,
        model: env['KANGOOS_LLM_MODEL'] ?? LlmSettings.defaults.model,
        apiKey: env['KANGOOS_LLM_API_KEY'] ?? '',
        baseUrl: env['KANGOOS_LLM_BASE_URL'] ?? '',
      ),
      embeddingModel: env['KANGOOS_EMBEDDING_MODEL'] ?? 'nomic-embed-text',
      ollamaBaseUrl: env['KANGOOS_OLLAMA_BASE_URL'] ?? 'http://localhost:11434',
      port: int.tryParse(env['PORT'] ?? '') ?? 8080,
      databaseEncryptionKey: databaseEncryptionKeyFromEnvironment(env),
    );
  }
}
