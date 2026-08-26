import '../database/database.dart';

class NewActivity {
  const NewActivity({
    required this.appName,
    required this.windowTitle,
    this.sourceId,
    this.capturedText,
    this.capturedUrl,
    this.capturedClipboard,
    this.capturedScreenText,
    this.capturedAudioText,
    this.capturedAt,
  });

  final String appName;
  final String windowTitle;
  final String? sourceId;
  final String? capturedText;
  final String? capturedUrl;
  final String? capturedClipboard;
  final String? capturedScreenText;
  final String? capturedAudioText;
  final DateTime? capturedAt;
}

abstract interface class ActivityRepository {
  Future<int> create(NewActivity activity);

  Future<Activity?> last();

  Stream<List<Activity>> watchRecent({int limit = 200});

  Future<List<Activity>> all();

  Future<List<Activity>> byIds(List<int> ids);

  Future<int> purgeOlderThan(DateTime cutoff);

  Future<List<Activity>> between(DateTime start, DateTime end, {int? limit});

  Stream<List<Activity>> watchBetween(DateTime start, DateTime end);

  Future<List<Activity>> search(
    String query, {
    DateTime? start,
    DateTime? end,
    int limit = 50,
  });

  Future<int> delete(int id);

  Future<int> clear();
}
