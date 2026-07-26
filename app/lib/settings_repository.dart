import 'package:kangoos_core/kangoos_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_credential_store.dart';

class SettingsRepository {
  SettingsRepository({SecureCredentialStore? secureStore})
      : _secureStore = secureStore ?? const FlutterSecureCredentialStore();

  final SecureCredentialStore _secureStore;

  static const _providerKey = 'llm_provider';
  static const _modelKey = 'llm_model';
  static const _baseUrlKey = 'llm_base_url';
  static const _reasoningEffortKey = 'llm_reasoning_effort';
  static const _embeddingModelKey = 'embedding_model';

  /// Same key in both stores: read from [SharedPreferences] is only ever a
  /// one-time migration off of the old plaintext-on-disk storage.
  static const _apiKeyKey = 'llm_api_key';

  Future<LlmSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = LlmProviderKind.values.firstWhere(
      (kind) => kind.name == prefs.getString(_providerKey),
      orElse: () => LlmSettings.defaults.provider,
    );
    final reasoningEffort = ReasoningEffort.values.firstWhere(
      (effort) => effort.name == prefs.getString(_reasoningEffortKey),
      orElse: () => LlmSettings.defaults.reasoningEffort,
    );

    return LlmSettings(
      provider: provider,
      model: prefs.getString(_modelKey) ?? LlmSettings.defaults.model,
      apiKey: await _readApiKey(prefs),
      baseUrl: prefs.getString(_baseUrlKey) ?? '',
      reasoningEffort: reasoningEffort,
      embeddingModel:
          prefs.getString(_embeddingModelKey) ?? defaultEmbeddingModel,
    );
  }

  Future<LlmSettings> loadEmbeddingSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return LlmSettings(
      provider: LlmProviderKind.ollama,
      baseUrl: prefs.getString(_baseUrlKey) ?? '',
      embeddingModel:
          prefs.getString(_embeddingModelKey) ?? defaultEmbeddingModel,
    );
  }

  /// Reads the API key from the OS keychain, migrating a pre-existing
  /// plaintext value out of [SharedPreferences] the first time it's read.
  Future<String> _readApiKey(SharedPreferences prefs) async {
    final secure = await _secureStore.read(_apiKeyKey);
    if (secure != null && secure.isNotEmpty) return secure;

    final legacyPlaintext = prefs.getString(_apiKeyKey);
    if (legacyPlaintext == null || legacyPlaintext.isEmpty) return '';

    await _secureStore.write(_apiKeyKey, legacyPlaintext);
    await prefs.remove(_apiKeyKey);
    return legacyPlaintext;
  }

  Future<void> save(LlmSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, settings.provider.name);
    await prefs.setString(_modelKey, settings.model);
    await prefs.setString(_baseUrlKey, settings.baseUrl);
    await prefs.setString(_reasoningEffortKey, settings.reasoningEffort.name);
    await prefs.setString(_embeddingModelKey, settings.embeddingModel);

    if (settings.apiKey.isEmpty) {
      await _secureStore.delete(_apiKeyKey);
    } else {
      await _secureStore.write(_apiKeyKey, settings.apiKey);
    }
    // Defensive: never leave a plaintext copy behind, even if load() (which
    // does the one-time migration) was never called before save().
    await prefs.remove(_apiKeyKey);
  }
}
