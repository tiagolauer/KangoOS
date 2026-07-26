import 'dart:math';

import 'package:drift/drift.dart' show Value;

import '../database/database.dart';
import '../embedding/embedding_provider.dart';

class SemanticMatch {
  const SemanticMatch({required this.snippet, required this.score});

  final Snippet snippet;
  final double score;
}

const defaultMinSimilarity = 0.5;

class SemanticSearch {
  SemanticSearch({
    required this.database,
    required this.embeddingProvider,
    this.minSimilarity = defaultMinSimilarity,
  });

  final KangoosDatabase database;
  final EmbeddingProvider embeddingProvider;
  final double minSimilarity;

  Future<void> indexSnippet(Snippet snippet) async {
    final embedding =
        await embeddingProvider.embed('${snippet.title}\n${snippet.content}');
    await database.updateSnippet(snippet.copyWith(embedding: Value(embedding)));
  }

  Future<int> createAndIndex(SnippetsCompanion entry) async {
    final id = await database.createSnippet(entry);
    final snippet = await database.getSnippetById(id);
    if (snippet != null) {
      await indexSnippet(snippet).catchError((Object _) {});
    }
    return id;
  }

  Future<int> indexMissingQuietly() async {
    try {
      return await indexMissing();
    } catch (_) {
      return 0;
    }
  }

  Future<int> indexMissing() async {
    final missing = await database.snippetsMissingEmbedding();
    for (final snippet in missing) {
      await indexSnippet(snippet);
    }
    return missing.length;
  }

  Future<List<SemanticMatch>> search(
    String query, {
    int limit = 5,
    double? minSimilarity,
  }) async {
    final floor = minSimilarity ?? this.minSimilarity;
    final queryEmbedding = await embeddingProvider.embed(query);
    final vectors = await database.snippetVectors();

    final scored = [
      for (final vector in vectors)
        if (vector.embedding.length == queryEmbedding.length)
          (
            id: vector.id,
            score: cosineSimilarity(queryEmbedding, vector.embedding),
          ),
    ]..sort((a, b) => b.score.compareTo(a.score));

    final top =
        scored.where((match) => match.score >= floor).take(limit).toList();
    final scoreById = {for (final match in top) match.id: match.score};
    final snippets =
        await database.snippetsByIds([for (final match in top) match.id]);

    return [
      for (final snippet in snippets)
        SemanticMatch(snippet: snippet, score: scoreById[snippet.id]!),
    ];
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
