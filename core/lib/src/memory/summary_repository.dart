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

  Future<List<ActivitySummary>> between(
    DateTime start,
    DateTime end, {
    int? limit,
  });

  Stream<List<ActivitySummary>> watchRecent({int limit = 50});

  Future<List<ActivitySummary>> all();

  Future<List<ActivitySummary>> recent({int limit = 5});

  Future<List<ActivitySummary>> searchKeyword(
    String query, {
    DateTime? start,
    DateTime? end,
    int limit = 50,
  });

  Future<List<ActivitySummary>> byIds(List<int> ids);

  Future<List<ActivitySummary>> pendingEmbedding(
    String providerId, {
    int? limit,
  });

  Future<List<ActivitySummaryVector>> vectors(String providerId);

  Future<void> setEmbedding(int id, List<double> embedding, String providerId);

  Future<int> purgeOlderThan(DateTime cutoff);

  Future<int> clear();
}
