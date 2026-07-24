import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_server/kangoos_server.dart';
import 'package:test/test.dart';

void main() {
  test('throws when KANGOOS_API_TOKEN is missing', () {
    expect(() => EnvConfig.fromEnvironment(const {}), throwsStateError);
  });

  test('applies defaults when only the token is set', () {
    final config = EnvConfig.fromEnvironment(const {'KANGOOS_API_TOKEN': 'secret'});

    expect(config.apiToken, 'secret');
    expect(config.dbPath, 'kangoos.db');
    expect(config.port, 8080);
    expect(config.embeddingModel, 'nomic-embed-text');
    expect(config.ollamaBaseUrl, 'http://localhost:11434');
    expect(config.llmSettings.provider, LlmProviderKind.ollama);
  });

  test('reads every override from the environment', () {
    final config = EnvConfig.fromEnvironment(const {
      'KANGOOS_API_TOKEN': 'secret',
      'KANGOOS_DB_PATH': '/data/kangoos.db',
      'KANGOOS_LLM_PROVIDER': 'anthropic',
      'KANGOOS_LLM_MODEL': 'claude-opus-4-8',
      'KANGOOS_LLM_API_KEY': 'sk-ant-test',
      'KANGOOS_EMBEDDING_MODEL': 'mxbai-embed-large',
      'KANGOOS_OLLAMA_BASE_URL': 'http://ollama:11434',
      'PORT': '9090',
    });

    expect(config.dbPath, '/data/kangoos.db');
    expect(config.llmSettings.provider, LlmProviderKind.anthropic);
    expect(config.llmSettings.model, 'claude-opus-4-8');
    expect(config.llmSettings.apiKey, 'sk-ant-test');
    expect(config.embeddingModel, 'mxbai-embed-large');
    expect(config.ollamaBaseUrl, 'http://ollama:11434');
    expect(config.port, 9090);
  });

  test('throws on an unknown provider name', () {
    expect(
      () => EnvConfig.fromEnvironment(const {
        'KANGOOS_API_TOKEN': 'secret',
        'KANGOOS_LLM_PROVIDER': 'not-a-provider',
      }),
      throwsStateError,
    );
  });
}
