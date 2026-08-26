import 'package:drift/drift.dart' show Value;

import '../../database/database.dart';
import '../../memory/activity_repository.dart';

class SqliteActivityRepository implements ActivityRepository {
  const SqliteActivityRepository(this.database);

  final KangoosDatabase database;

  @override
  Future<int> create(NewActivity activity) => database.logActivity(
        ActivitiesCompanion.insert(
          appName: activity.appName,
          windowTitle: activity.windowTitle,
          capturedText: Value(activity.capturedText),
          capturedUrl: Value(activity.capturedUrl),
          capturedClipboard: Value(activity.capturedClipboard),
          capturedScreenText: Value(activity.capturedScreenText),
          capturedAudioText: Value(activity.capturedAudioText),
          capturedAt: activity.capturedAt == null
              ? const Value.absent()
              : Value(activity.capturedAt!),
        ),
      );

  @override
  Future<Activity?> last() => database.lastActivity();

  @override
  Stream<List<Activity>> watchRecent({int limit = 200}) =>
      database.watchRecentActivities(limit: limit);

  @override
  Future<List<Activity>> all() => database.allActivities();

  @override
  Future<int> purgeOlderThan(DateTime cutoff) =>
      database.purgeActivitiesOlderThan(cutoff);

  @override
  Future<List<Activity>> between(
    DateTime start,
    DateTime end, {
    int? limit,
  }) =>
      database.activitiesBetween(start, end, limit: limit);

  @override
  Stream<List<Activity>> watchBetween(DateTime start, DateTime end) =>
      database.watchActivitiesBetween(start, end);

  @override
  Future<List<Activity>> search(
    String query, {
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) =>
      database.searchActivities(query, start: start, end: end, limit: limit);

  @override
  Future<int> delete(int id) => database.deleteActivity(id);

  @override
  Future<int> clear() => database.clearAllActivity();
}
