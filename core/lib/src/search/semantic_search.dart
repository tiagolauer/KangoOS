import '../database/database.dart';
import '../embedding/embedding_provider.dart';
import '../snippets/snippet_repository.dart';
import 'vector_index.dart';

class SemanticMatch {
  const SemanticMatch({required this.snippet, required this.score});

  final Snippet snippet;
  final double score;
}

class SnippetIndexingReport {
  const SnippetIndexingReport({
    required this.indexed,
    required this.failures,
  });

  final int indexed;
  final Map<int, Object> failures;
}

const defaultMinSimilarity = 0.5;

class SemanticSearch {
  SemanticSearch({
    required this.repository,
    required this.embeddingProvider,
    this.minSimilarity = defaultMinSimilarity,
    this.vectorIndex = const BruteForceVectorIndex(),
  });

  final SnippetRepository repository;
  final EmbeddingProvider embeddingProvider;
  final double minSimilarity;
  final VectorIndex<int> vectorIndex;

  Future<void> indexSnippet(Snippet snippet) async {
    final providerId = await _providerFingerprint();
    final embedding =
        await embeddingProvider.embed('${snippet.title}\n${snippet.content}');
    await repository.setEmbedding(snippet.id, embedding, providerId);
  }

  Future<SnippetIndexingReport> indexPending() async {
    final providerId = await _providerFingerprint();
    final pending = await repository.pendingEmbedding(providerId);
    var indexed = 0;
    final failures = <int, Object>{};
    for (final snippet in pending) {
      try {
        await indexSnippet(snippet);
        indexed++;
      } catch (error) {
        failures[snippet.id] = error;
      }
    }
    return SnippetIndexingReport(indexed: indexed, failures: failures);
  }

  Future<List<SemanticMatch>> search(
    String query, {
    int limit = 5,
    double? minSimilarity,
  }) async {
    final floor = minSimilarity ?? this.minSimilarity;
    final providerId = await _providerFingerprint();
    final queryEmbedding = await embeddingProvider.embed(query);
    final vectors = await repository.vectors(providerId);

    final top = vectorIndex.search(
      queryEmbedding,
      vectors.map(
        (vector) => VectorEntry(key: vector.id, vector: vector.embedding),
      ),
      limit: limit,
      minScore: floor,
    );
    final scoreById = {for (final match in top) match.key: match.score};
    final snippets = await repository.byIds([
      for (final match in top) match.key,
    ]);

    return [
      for (final snippet in snippets)
        SemanticMatch(snippet: snippet, score: scoreById[snippet.id]!),
    ];
  }

  Future<String> _providerFingerprint() async {
    return embeddingProviderFingerprint(embeddingProvider);
  }
}
