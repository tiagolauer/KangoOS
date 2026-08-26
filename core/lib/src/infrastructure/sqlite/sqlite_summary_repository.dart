import 'package:drift/drift.dart' show Value;

import '../../database/database.dart';
import '../../memory/summary_repository.dart';

class SqliteSummaryRepository implements SummaryRepository {
  const SqliteSummaryRepository(this.database);

  final KangoosDatabase database;

  @override
  Future<int> create(NewActivitySummary summary) =>
      database.insertActivitySummary(ActivitySummariesCompanion.insert(
        kind: summary.kind,
        periodStart: summary.periodStart,
        periodEnd: summary.periodEnd,
        content: summary.content,
        createdAt: summary.createdAt == null
            ? const Value.absent()
            : Value(summary.createdAt!),
      ));

  @override
  Future<ActivitySummary?> getById(int id) => database.getSummaryById(id);

  @override
  Future<List<ActivitySummary>> between(DateTime start, DateTime end) =>
      database.summariesBetween(start, end);

  @override
  Stream<List<ActivitySummary>> watchRecent({int limit = 50}) =>
      database.watchRecentSummaries(limit: limit);

  @override
  Future<List<ActivitySummary>> all() => database.allSummaries();

  @override
  Future<List<ActivitySummary>> recent({int limit = 5}) =>
      database.recentSummaries(limit: limit);

  @override
  Future<int> purgeOlderThan(DateTime cutoff) =>
      database.purgeSummariesOlderThan(cutoff);

  @override
  Future<int> clear() => database.clearAllSummaries();
}
