import 'dart:io';

import '../database/database.dart';
import '../database/tables/activity_summaries_table.dart';
import '../embedding/embedding_provider.dart';
import 'activity_repository.dart';
import 'episode_repository.dart';
import 'memory_deletion.dart';
import 'memory_metrics.dart';
import 'memory_query_engine.dart';
import 'privacy_filter.dart';
import 'summary_repository.dart';

typedef MemoryClearResult = MemoryDeletionResult;

typedef PrivacyFilterProvider = Future<PrivacyFilter> Function();

class MemoryService {
  MemoryService({
    required this.database,
    required this.activities,
    required this.summaries,
    this.episodes,
    this.queryEngine,
    this.privacyFilter = const PrivacyFilter(),
    this.privacyFilterProvider,
    this.metrics,
  });

  final KangoosDatabase database;
  final ActivityRepository activities;
  final SummaryRepository summaries;
  final EpisodeRepository? episodes;
  final MemoryQueryEngine? queryEngine;
  final PrivacyFilter privacyFilter;
  final PrivacyFilterProvider? privacyFilterProvider;
  final LocalMemoryMetrics? metrics;

  Future<int> record(NewActivity activity) async =>
      activities.create((await _privacyFilter()).filterActivity(activity));

  Stream<List<Activity>> watchRecentActivities({int limit = 200}) =>
      activities.watchRecent(limit: limit);

  Stream<List<ActivitySummary>> watchRecentSummaries({int limit = 50}) =>
      summaries.watchRecent(limit: limit);

  Future<List<Activity>> between(DateTime start, DateTime end, {int? limit}) =>
      activities.between(start, end, limit: limit);

  Stream<List<Activity>> watchBetween(DateTime start, DateTime end) =>
      activities.watchBetween(start, end);

  Future<List<Activity>> search(
    String query, {
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) => activities.search(query, start: start, end: end, limit: limit);

  Future<List<ActivitySummary>> summariesBetween(
    DateTime start,
    DateTime end,
  ) => summaries.between(start, end);

  Future<List<ActivitySummary>> recentSummaries({int limit = 5}) =>
      summaries.recent(limit: limit);

  Future<ActivitySummary> remember(
    String content, {
    DateTime? at,
    DateTime? endAt,
    SummaryKind kind = SummaryKind.durable,
  }) async {
    final timestamp = at ?? DateTime.now();
    final periodEnd = endAt ?? timestamp;
    if (periodEnd.isBefore(timestamp)) {
      throw ArgumentError.value(endAt, 'endAt', 'must not be before at');
    }
    final filtered = (await _privacyFilter()).filter(content) ?? content;
    final id = await summaries.create(
      NewActivitySummary(
        kind: kind,
        periodStart: timestamp,
        periodEnd: periodEnd,
        content: filtered,
        createdAt: timestamp,
      ),
    );
    final created = await summaries.getById(id);
    if (created == null) {
      throw StateError('Created memory #$id could not be loaded.');
    }
    return created;
  }

  Future<int> forgetSummary(int id) => summaries.delete(id);

  Future<int> deleteActivity(int id) async =>
      (await delete(MemoryDeletionFilter(activityIds: {id}))).activities;

  Future<List<String>> knownApplications() async {
    final names =
        (await activities.all())
            .map((activity) => activity.appName.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  Future<List<MemoryEpisode>> recentEpisodes({int limit = 50}) =>
      episodes?.recent(limit: limit) ?? Future.value(const []);

  Future<MemoryEpisode?> getEpisode(int id) async => episodes?.get(id);

  Future<int> forgetEpisode(int id) async => (await episodes?.delete(id)) ?? 0;

  Future<MemorySearchResult> searchEpisodes(
    String query, {
    DateTime? reference,
    int limit = 10,
    MemorySearchMode mode = MemorySearchMode.hybrid,
    MemorySearchFilters filters = const MemorySearchFilters(),
  }) =>
      queryEngine?.search(
        query,
        reference: reference,
        limit: limit,
        mode: mode,
        filters: MemorySearchFilters(
          sources: const {MemoryEvidenceSource.episode},
          applications: filters.applications,
          modalities: filters.modalities,
          projects: filters.projects,
          start: filters.start,
          end: filters.end,
        ),
      ) ??
      Future.value(const MemorySearchResult(matches: []));

  Future<MemorySearchResult> searchMemory(
    String query, {
    DateTime? reference,
    int limit = 10,
    MemorySearchMode mode = MemorySearchMode.hybrid,
    MemorySearchFilters filters = const MemorySearchFilters(),
  }) =>
      queryEngine?.search(
        query,
        reference: reference,
        limit: limit,
        mode: mode,
        filters: filters,
      ) ??
      Future.value(const MemorySearchResult());

  Future<MemoryDeletionPreview> previewDeletion(MemoryDeletionFilter filter) =>
      database.previewMemoryDeletion(filter);

  Future<MemoryDeletionResult> delete(MemoryDeletionFilter filter) =>
      database.deleteMemory(filter);

  Future<MemoryClearResult> clear() => delete(const MemoryDeletionFilter());

  Future<MemoryClearResult> purgeOlderThan(DateTime cutoff) async =>
      delete(MemoryDeletionFilter(end: cutoff));

  Future<File> createBackup(File destination) =>
      database.createBackup(destination);

  Future<File> stageRestore(File backup) => database.stageRestore(backup);

  Future<MemoryDiagnosticsSnapshot> diagnostics() async {
    final provider = queryEngine?.embeddingProvider;
    final providerId =
        provider == null ? null : await embeddingProviderFingerprint(provider);
    return MemoryDiagnosticsService(
      database: database,
      metrics: metrics,
    ).snapshot(providerId: providerId);
  }

  Future<PrivacyFilter> _privacyFilter() async =>
      await privacyFilterProvider?.call() ?? privacyFilter;
}
