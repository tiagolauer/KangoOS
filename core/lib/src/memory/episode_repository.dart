import '../database/database.dart';
import '../database/tables/memory_episodes_table.dart';

const currentMemoryFormationVersion = 2;
const deterministicMemoryConfidence = 0.5;

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
    this.formationVersion = currentMemoryFormationVersion,
    this.contentHash = '',
    this.formationStatus = MemoryFormationStatus.deterministic,
    this.confidence = deterministicMemoryConfidence,
    this.decisions = const [],
    this.actionItems = const [],
    this.technologies = const [],
    this.formationModelId,
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
  final int formationVersion;
  final String contentHash;
  final MemoryFormationStatus formationStatus;
  final double confidence;
  final List<String> decisions;
  final List<String> actionItems;
  final List<String> technologies;
  final String? formationModelId;

  NewMemoryEpisode copyWith({
    String? title,
    String? summary,
    List<String>? applications,
    List<String>? urls,
    List<String>? topics,
    List<String>? entities,
    int? formationVersion,
    String? contentHash,
    MemoryFormationStatus? formationStatus,
    double? confidence,
    List<String>? decisions,
    List<String>? actionItems,
    List<String>? technologies,
    String? formationModelId,
    bool clearFormationModelId = false,
  }) => NewMemoryEpisode(
    sourceKey: sourceKey,
    startedAt: startedAt,
    endedAt: endedAt,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    applications: applications ?? this.applications,
    urls: urls ?? this.urls,
    topics: topics ?? this.topics,
    entities: entities ?? this.entities,
    sourceActivityIds: sourceActivityIds,
    formationVersion: formationVersion ?? this.formationVersion,
    contentHash: contentHash ?? this.contentHash,
    formationStatus: formationStatus ?? this.formationStatus,
    confidence: confidence ?? this.confidence,
    decisions: decisions ?? this.decisions,
    actionItems: actionItems ?? this.actionItems,
    technologies: technologies ?? this.technologies,
    formationModelId:
        clearFormationModelId
            ? null
            : formationModelId ?? this.formationModelId,
  );
}

class EpisodeVector {
  const EpisodeVector({required this.id, required this.embedding});

  final int id;
  final List<double> embedding;
}

abstract interface class EpisodeRepository {
  Future<int> create(NewMemoryEpisode episode);

  Future<void> replace(int id, NewMemoryEpisode episode);

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

  Future<void> setEmbedding(int id, List<double> embedding, String providerId);

  Future<int> delete(int id);

  Future<int> purgeOlderThan(DateTime cutoff);

  Future<int> clear();
}
