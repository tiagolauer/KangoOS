import '../database/database.dart';

class NewMemoryEpisode {
  const NewMemoryEpisode({
    required this.sourceKey,
    required this.startedAt,
    required this.endedAt,
    required this.title,
    required this.summary,
    required this.applications,
    required this.urls,
    required this.topics,
    required this.entities,
    required this.sourceActivityIds,
  });

  final String sourceKey;
  final DateTime startedAt;
  final DateTime endedAt;
  final String title;
  final String summary;
  final List<String> applications;
  final List<String> urls;
  final List<String> topics;
  final List<String> entities;
  final List<int> sourceActivityIds;
}

class EpisodeVector {
  const EpisodeVector({required this.id, required this.embedding});

  final int id;
  final List<double> embedding;
}

abstract interface class EpisodeRepository {
  Future<int> create(NewMemoryEpisode episode);

  Future<MemoryEpisode?> get(int id);

  Future<MemoryEpisode?> bySourceKey(String sourceKey);

  Future<List<MemoryEpisode>> byIds(List<int> ids);

  Future<List<MemoryEpisode>> recent({int limit = 50});

  Future<List<MemoryEpisode>> between(DateTime start, DateTime end);

  Future<List<MemoryEpisode>> searchKeyword(
    String query, {
    DateTime? start,
    DateTime? end,
    int limit = 50,
  });

  Future<List<MemoryEpisode>> pendingEmbedding(String providerId);

  Future<List<EpisodeVector>> vectors(String providerId);

  Future<void> setEmbedding(
    int id,
    List<double> embedding,
    String providerId,
  );

  Future<int> delete(int id);

  Future<int> purgeOlderThan(DateTime cutoff);

  Future<int> clear();
}
