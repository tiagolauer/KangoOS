import 'package:kangoos_core/kangoos_core.dart';

import '../settings_repository.dart';

class SettingsEmbeddingProvider
    implements EmbeddingProvider, DynamicEmbeddingProvider {
  SettingsEmbeddingProvider({required this.repository});

  final SettingsRepository repository;

  EmbeddingProvider? _provider;
  String? _providerKey;

  @override
  String get id => _provider?.id ?? 'ollama:unresolved';

  @override
  Future<String> resolveFingerprint() async {
    await _resolveProvider();
    return _provider!.id;
  }

  @override
  Future<List<double>> embed(String text) async {
    await _resolveProvider();
    return _provider!.embed(text);
  }

  Future<void> _resolveProvider() async {
    final settings = await repository.loadEmbeddingSettings();
    final key = '${settings.provider.name}|${settings.baseUrl}|'
        '${settings.embeddingModel}|${settings.apiKey.isNotEmpty}';
    if (key != _providerKey) {
      _provider = settings.buildEmbeddingProvider();
      _providerKey = key;
    }
  }
}
