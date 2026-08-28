abstract class EmbeddingProvider {
  String get id;

  Future<List<double>> embed(String text);
}

abstract interface class DynamicEmbeddingProvider {
  Future<String> resolveFingerprint();
}

Future<String> embeddingProviderFingerprint(EmbeddingProvider provider) =>
    provider is DynamicEmbeddingProvider
        ? (provider as DynamicEmbeddingProvider).resolveFingerprint()
        : Future.value(provider.id);
