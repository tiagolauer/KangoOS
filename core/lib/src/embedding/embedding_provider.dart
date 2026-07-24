abstract class EmbeddingProvider {
  String get id;

  Future<List<double>> embed(String text);
}
