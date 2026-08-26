import '../chat/temporal_query.dart';
import '../database/database.dart';
import '../embedding/embedding_provider.dart';
import '../search/vector_index.dart';
import 'episode_repository.dart';

class MemoryMatch {
  const MemoryMatch({
    required this.episode,
    required this.score,
    required this.lexical,
    required this.semantic,
  });

  final MemoryEpisode episode;
  final double score;
  final bool lexical;
  final bool semantic;
}

class MemorySearchResult {
  const MemorySearchResult({required this.matches, this.semanticError});

  final List<MemoryMatch> matches;
  final Object? semanticError;
}

enum MemorySearchMode { hybrid, lexical, semantic, temporal }

class MemoryQueryEngine {
  const MemoryQueryEngine({
    required this.episodes,
    this.embeddingProvider,
    this.temporalParser = const RuleBasedTemporalParser(),
    this.vectorIndex = const BruteForceVectorIndex(),
  });

  final EpisodeRepository episodes;
  final EmbeddingProvider? embeddingProvider;
  final TemporalParser temporalParser;
  final VectorIndex<int> vectorIndex;

  Future<MemorySearchResult> search(
    String query, {
    DateTime? reference,
    int limit = 10,
    MemorySearchMode mode = MemorySearchMode.hybrid,
  }) async {
    final temporal = await temporalParser.parse(
      query,
      reference ?? DateTime.now(),
    );
    final scores = <int, double>{};
    final lexicalIds = <int>{};
    final semanticIds = <int>{};
    if (mode == MemorySearchMode.hybrid || mode == MemorySearchMode.lexical) {
      final lexical = await episodes.searchKeyword(
        query,
        start: temporal.start,
        end: temporal.end,
        limit: limit * 2,
      );
      for (var index = 0; index < lexical.length; index++) {
        final id = lexical[index].id;
        lexicalIds.add(id);
        scores[id] = (scores[id] ?? 0) + 0.4 / (index + 1);
      }
    }

    Object? semanticError;
    final provider = embeddingProvider;
    if (provider != null &&
        query.trim().isNotEmpty &&
        (mode == MemorySearchMode.hybrid ||
            mode == MemorySearchMode.semantic)) {
      try {
        final providerId = await embeddingProviderFingerprint(provider);
        final queryVector = await provider.embed(query);
        final semantic = vectorIndex.search(
          queryVector,
          (await episodes.vectors(providerId)).map(
            (vector) => VectorEntry(
              key: vector.id,
              vector: vector.embedding,
            ),
          ),
          limit: limit * 2,
          minScore: -1,
        );
        for (final match in semantic) {
          semanticIds.add(match.key);
          scores[match.key] = (scores[match.key] ?? 0) + match.score * 0.6;
        }
      } catch (error) {
        semanticError = error;
      }
    }

    if ((mode == MemorySearchMode.temporal ||
            (mode == MemorySearchMode.hybrid && scores.isEmpty)) &&
        temporal.start != null &&
        temporal.end != null) {
      final timed = await episodes.between(temporal.start!, temporal.end!);
      for (var index = 0; index < timed.length; index++) {
        scores[timed[index].id] = 0.2 / (index + 1);
      }
    }

    final candidates = await episodes.byIds(scores.keys.toList());
    final filtered = candidates.where((episode) {
      final start = temporal.start;
      final end = temporal.end;
      return (start == null || episode.endedAt.isAfter(start)) &&
          (end == null || episode.startedAt.isBefore(end));
    }).toList()
      ..sort((a, b) => (scores[b.id] ?? 0).compareTo(scores[a.id] ?? 0));
    return MemorySearchResult(
      semanticError: semanticError,
      matches: [
        for (final episode in filtered.take(limit))
          MemoryMatch(
            episode: episode,
            score: scores[episode.id] ?? 0,
            lexical: lexicalIds.contains(episode.id),
            semantic: semanticIds.contains(episode.id),
          ),
      ],
    );
  }
}
