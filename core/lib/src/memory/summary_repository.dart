import '../database/database.dart';
import '../database/tables/activity_summaries_table.dart';

class NewActivitySummary {
  const NewActivitySummary({
    required this.kind,
    required this.periodStart,
    required this.periodEnd,
    required this.content,
    this.createdAt,
  });

  final SummaryKind kind;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String content;
  final DateTime? createdAt;
}

abstract interface class SummaryRepository {
  Future<int> create(NewActivitySummary summary);

  Future<ActivitySummary?> getById(int id);

  Future<List<ActivitySummary>> between(DateTime start, DateTime end);

  Stream<List<ActivitySummary>> watchRecent({int limit = 50});

  Future<List<ActivitySummary>> all();

  Future<List<ActivitySummary>> recent({int limit = 5});

  Future<int> purgeOlderThan(DateTime cutoff);

  Future<int> clear();
}
