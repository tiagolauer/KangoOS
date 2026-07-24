import 'dart:math';

import 'package:drift/drift.dart' show Value;

import '../database/database.dart';
import '../embedding/embedding_provider.dart';

class SemanticMatch {
  const SemanticMatch({required this.snippet, required this.score});

  final Snippet snippet;
  final double score;
}

class SemanticSearch {
  SemanticSearch({required this.database, required this.embeddingProvider});

  final KangoosDatabase database;
  final EmbeddingProvider embeddingProvider;

  Future<void> indexSnippet(Snippet snippet) async {
    final embedding = await embeddingProvider.embed('${snippet.title}\n${snippet.content}');
    await database.updateSnippet(snippet.copyWith(embedding: Value(embedding)));
  }

  Future<int> indexMissing() async {
    final missing = await database.snippetsMissingEmbedding();
    for (final snippet in missing) {
      await indexSnippet(snippet);
    }
    return missing.length;
  }

  Future<List<SemanticMatch>> search(String query, {int limit = 5}) async {
    final queryEmbedding = await embeddingProvider.embed(query);
    final candidates = await database.snippetsWithEmbedding();

    final matches = candidates
        .map((snippet) => SemanticMatch(
              snippet: snippet,
              score: cosineSimilarity(queryEmbedding, snippet.embedding!),
            ))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return matches.take(limit).toList();
  }
}

double cosineSimilarity(List<double> a, List<double> b) {
  final length = min(a.length, b.length);
  var dot = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var i = 0; i < length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  if (normA == 0 || normB == 0) return 0;
  return dot / (sqrt(normA) * sqrt(normB));
}
