import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kangoos_app/secure_credential_store.dart';
import 'package:kangoos_app/settings_repository.dart';

class _FakeSecureCredentialStore implements SecureCredentialStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

void main() {
  test('save writes the API key to the secure store, not SharedPreferences',
      () async {
    SharedPreferences.setMockInitialValues({});
    final secureStore = _FakeSecureCredentialStore();
    final repository = SettingsRepository(secureStore: secureStore);

    await repository.save(const LlmSettings(
      provider: LlmProviderKind.openAi,
      model: 'gpt-4o',
      apiKey: 'sk-secret',
    ));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('llm_api_key'), isNull);
    expect(await secureStore.read('llm_api_key'), 'sk-secret');
    expect((await repository.load()).apiKey, 'sk-secret');
  });

  test('load migrates a pre-existing plaintext key out of SharedPreferences',
      () async {
    SharedPreferences.setMockInitialValues({'llm_api_key': 'sk-old-plaintext'});
    final secureStore = _FakeSecureCredentialStore();
    final repository = SettingsRepository(secureStore: secureStore);

    final settings = await repository.load();

    expect(settings.apiKey, 'sk-old-plaintext');
    expect(await secureStore.read('llm_api_key'), 'sk-old-plaintext');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('llm_api_key'), isNull);
  });

  test('the secure store value wins if both stores somehow have a value',
      () async {
    SharedPreferences.setMockInitialValues(
        {'llm_api_key': 'sk-stale-plaintext'});
    final secureStore = _FakeSecureCredentialStore();
    await secureStore.write('llm_api_key', 'sk-current');
    final repository = SettingsRepository(secureStore: secureStore);

    expect((await repository.load()).apiKey, 'sk-current');
  });

  test('saving an empty API key clears the secure store entry', () async {
    SharedPreferences.setMockInitialValues({});
    final secureStore = _FakeSecureCredentialStore();
    final repository = SettingsRepository(secureStore: secureStore);
    await repository.save(
        const LlmSettings(provider: LlmProviderKind.openAi, apiKey: 'sk-x'));

    await repository
        .save(const LlmSettings(provider: LlmProviderKind.openAi, apiKey: ''));

    expect(await secureStore.read('llm_api_key'), isNull);
    expect((await repository.load()).apiKey, '');
  });

  test('non-secret settings still round-trip through SharedPreferences',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repository =
        SettingsRepository(secureStore: _FakeSecureCredentialStore());

    await repository.save(const LlmSettings(
      provider: LlmProviderKind.anthropic,
      model: 'claude-opus-4-8',
      baseUrl: 'https://example.com',
      reasoningEffort: ReasoningEffort.thinking,
    ));

    final settings = await repository.load();
    expect(settings.provider, LlmProviderKind.anthropic);
    expect(settings.model, 'claude-opus-4-8');
    expect(settings.baseUrl, 'https://example.com');
    expect(settings.reasoningEffort, ReasoningEffort.thinking);
  });

  test('the embedding provider follows the configured base URL and model',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repository =
        SettingsRepository(secureStore: _FakeSecureCredentialStore());

    await repository.save(const LlmSettings(
      provider: LlmProviderKind.ollama,
      model: 'llama3',
      baseUrl: 'http://nas.local:11434',
      embeddingModel: 'mxbai-embed-large',
    ));

    final provider = (await repository.loadEmbeddingSettings())
        .buildEmbeddingProvider() as OllamaEmbeddingProvider;

    expect(provider.baseUrl, 'http://nas.local:11434');
    expect(provider.model, 'mxbai-embed-large');
  });

  test('the embedding provider falls back to the Ollama defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final repository =
        SettingsRepository(secureStore: _FakeSecureCredentialStore());

    final provider = (await repository.loadEmbeddingSettings())
        .buildEmbeddingProvider() as OllamaEmbeddingProvider;

    expect(provider.baseUrl, defaultOllamaBaseUrl);
    expect(provider.model, defaultEmbeddingModel);
  });
}
