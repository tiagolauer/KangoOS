import 'package:drift/drift.dart' show Value;

import '../../database/database.dart';
import '../../database/tables/activity_summaries_table.dart';
import '../../memory/summary_repository.dart';

class SqliteSummaryRepository implements SummaryRepository {
  const SqliteSummaryRepository(this.database);

  final KangoosDatabase database;

  @override
  Future<int> create(NewActivitySummary summary) =>
      database.insertActivitySummary(
        ActivitySummariesCompanion.insert(
          kind: summary.kind,
          periodStart: summary.periodStart,
          periodEnd: summary.periodEnd,
          content: summary.content,
          createdAt:
              summary.createdAt == null
                  ? const Value.absent()
                  : Value(summary.createdAt!),
        ),
      );

  @override
  Future<ActivitySummary?> getById(int id) => database.getSummaryById(id);

  @override
  Future<List<ActivitySummary>> between(
    DateTime start,
    DateTime end, {
    int? limit,
  }) => database.summariesBetween(start, end, limit: limit);

  @override
  Stream<List<ActivitySummary>> watchRecent({int limit = 50}) =>
      database.watchRecentSummaries(limit: limit);

  @override
  Future<List<ActivitySummary>> all() => database.allSummaries();

  @override
  Future<List<ActivitySummary>> recent({int limit = 5}) =>
      database.recentSummaries(limit: limit);

  @override
  Future<List<ActivitySummary>> searchKeyword(
    String query, {
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) => database.searchActivitySummaries(
    query,
    start: start,
    end: end,
    limit: limit,
  );

  @override
  Future<List<ActivitySummary>> byIds(List<int> ids) =>
      database.summariesByIds(ids);

  @override
  Future<List<ActivitySummary>> pendingEmbedding(
    String providerId, {
    int? limit,
  }) => database.summariesPendingEmbedding(providerId, limit: limit);

  @override
  Future<List<ActivitySummaryVector>> vectors(String providerId) =>
      database.activitySummaryVectors(providerId);

  @override
  Future<void> setEmbedding(
    int id,
    List<double> embedding,
    String providerId,
  ) => database.setActivitySummaryEmbedding(id, embedding, providerId);

  @override
  Future<int> delete(int id) => database.deleteActivitySummary(id);

  @override
  Future<int> purgeOlderThan(DateTime cutoff) =>
      database.purgeSummariesOlderThan(cutoff);

  @override
  Future<int> clear() => database.clearAllSummaries();
}
