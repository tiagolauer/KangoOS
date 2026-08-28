import 'dart:math';

class VectorEntry<T> {
  const VectorEntry({required this.key, required this.vector});

  final T key;
  final List<double> vector;
}

class VectorMatch<T> {
  const VectorMatch({required this.key, required this.score});

  final T key;
  final double score;
}

abstract interface class VectorIndex<T> {
  List<VectorMatch<T>> search(
    List<double> query,
    Iterable<VectorEntry<T>> entries, {
    required int limit,
    required double minScore,
  });
}

class BruteForceVectorIndex<T> implements VectorIndex<T> {
  const BruteForceVectorIndex();

  @override
  List<VectorMatch<T>> search(
    List<double> query,
    Iterable<VectorEntry<T>> entries, {
    required int limit,
    required double minScore,
  }) {
    if (limit <= 0 || query.isEmpty) return const [];
    final matches = [
      for (final entry in entries)
        if (entry.vector.length == query.length)
          VectorMatch(
            key: entry.key,
            score: cosineSimilarity(query, entry.vector),
          ),
    ]
      ..removeWhere((match) => match.score < minScore)
      ..sort((a, b) => b.score.compareTo(a.score));
    return matches.take(limit).toList();
  }
}

double cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length) {
    throw ArgumentError(
        'Embeddings have different dimensions (${a.length} vs ${b.length}); '
        'they come from different models and cannot be compared.');
  }
  var dot = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA == 0 || normB == 0) return 0;
  return dot / (sqrt(normA) * sqrt(normB));
}
