import 'package:drift/drift.dart';

import '../../database/database.dart';
import '../../database/tables/snippets_table.dart';
import '../../memory/episode_repository.dart';

class SqliteEpisodeRepository implements EpisodeRepository {
  const SqliteEpisodeRepository(this.database);

  final KangoosDatabase database;

  @override
  Future<int> create(NewMemoryEpisode episode) =>
      database.into(database.memoryEpisodes).insert(
            MemoryEpisodesCompanion.insert(
              sourceKey: episode.sourceKey,
              startedAt: episode.startedAt,
              endedAt: episode.endedAt,
              title: episode.title,
              summary: episode.summary,
              applications: Value(episode.applications),
              urls: Value(episode.urls),
              topics: Value(episode.topics),
              entities: Value(episode.entities),
              sourceActivityIds: Value(episode.sourceActivityIds),
            ),
          );

  @override
  Future<MemoryEpisode?> get(int id) =>
      (database.select(database.memoryEpisodes)
            ..where((row) => row.id.equals(id)))
          .getSingleOrNull();

  @override
  Future<MemoryEpisode?> bySourceKey(String sourceKey) =>
      (database.select(database.memoryEpisodes)
            ..where((row) => row.sourceKey.equals(sourceKey)))
          .getSingleOrNull();

  @override
  Future<List<MemoryEpisode>> byIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final found = await (database.select(database.memoryEpisodes)
          ..where((row) => row.id.isIn(ids)))
        .get();
    final byId = {for (final episode in found) episode.id: episode};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!
    ];
  }

  @override
  Future<List<MemoryEpisode>> recent({int limit = 50}) =>
      (database.select(database.memoryEpisodes)
            ..orderBy([(row) => OrderingTerm.desc(row.endedAt)])
            ..limit(limit))
          .get();

  @override
  Future<List<MemoryEpisode>> between(DateTime start, DateTime end) =>
      (database.select(database.memoryEpisodes)
            ..where((row) =>
                row.endedAt.isBiggerThanValue(start) &
                row.startedAt.isSmallerThanValue(end))
            ..orderBy([(row) => OrderingTerm.asc(row.startedAt)]))
          .get();

  @override
  Future<List<MemoryEpisode>> searchKeyword(
    String query, {
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) async {
    final matchQuery = ftsMatchQuery(query);
    if (matchQuery.isEmpty) return const [];
    final sql = StringBuffer(
      'SELECT e.* FROM memory_episodes e '
      'JOIN memory_episodes_fts ON memory_episodes_fts.rowid = e.id '
      'WHERE memory_episodes_fts MATCH ?',
    );
    final variables = <Variable>[Variable.withString(matchQuery)];
    if (start != null) {
      sql.write(' AND e.ended_at > ?');
      variables.add(Variable.withDateTime(start));
    }
    if (end != null) {
      sql.write(' AND e.started_at < ?');
      variables.add(Variable.withDateTime(end));
    }
    sql.write(' ORDER BY rank LIMIT ?');
    variables.add(Variable.withInt(limit));
    final rows = await database.customSelect(
      sql.toString(),
      variables: variables,
      readsFrom: {database.memoryEpisodes},
    ).get();
    return rows.map((row) => database.memoryEpisodes.map(row.data)).toList();
  }

  @override
  Future<List<MemoryEpisode>> pendingEmbedding(String providerId) =>
      (database.select(database.memoryEpisodes)
            ..where((row) =>
                row.embedding.isNull() |
                row.embeddingProviderId.isNull() |
                row.embeddingProviderId.equals(providerId).not()))
          .get();

  @override
  Future<List<EpisodeVector>> vectors(String providerId) async {
    final rows = await database.customSelect(
      'SELECT id, embedding FROM memory_episodes '
      'WHERE embedding IS NOT NULL AND embedding_provider_id = ?;',
      variables: [Variable.withString(providerId)],
      readsFrom: {database.memoryEpisodes},
    ).get();
    const converter = EmbeddingConverter();
    return rows
        .map((row) => EpisodeVector(
              id: row.read<int>('id'),
              embedding: converter.fromSql(row.read<Uint8List>('embedding')),
            ))
        .toList();
  }

  @override
  Future<void> setEmbedding(
    int id,
    List<double> embedding,
    String providerId,
  ) =>
      (database.update(database.memoryEpisodes)
            ..where((row) => row.id.equals(id)))
          .write(MemoryEpisodesCompanion(
        embedding: Value(embedding),
        embeddingProviderId: Value(providerId),
      ));

  @override
  Future<int> delete(int id) => (database.delete(database.memoryEpisodes)
        ..where((row) => row.id.equals(id)))
      .go();

  @override
  Future<int> purgeOlderThan(DateTime cutoff) =>
      (database.delete(database.memoryEpisodes)
            ..where((row) => row.endedAt.isSmallerOrEqualValue(cutoff)))
          .go();

  @override
  Future<int> clear() => database.delete(database.memoryEpisodes).go();
}
