import 'package:kangoos_core/kangoos_core.dart';

import '../settings_repository.dart';

class SettingsEmbeddingProvider implements EmbeddingProvider {
  SettingsEmbeddingProvider({required this.repository});

  final SettingsRepository repository;

  EmbeddingProvider? _provider;
  String? _providerKey;

  @override
  String get id => 'ollama';

  @override
  Future<List<double>> embed(String text) async {
    final settings = await repository.loadEmbeddingSettings();
    final key = '${settings.ollamaBaseUrl}|${settings.embeddingModel}';
    if (key != _providerKey) {
      _provider = settings.buildEmbeddingProvider();
      _providerKey = key;
    }
    return _provider!.embed(text);
  }
}
