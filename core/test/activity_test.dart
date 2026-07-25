import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:kangoos_core/kangoos_core.dart';
import 'package:test/test.dart';

void main() {
  late KangoosDatabase database;

  setUp(() => database = KangoosDatabase.memory());
  tearDown(() => database.close());

  test('logActivity stores a row, lastActivity and watchRecentActivities read it back',
      () async {
    expect(await database.lastActivity(), isNull);

    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'Code.exe',
      windowTitle: 'main.dart - KangoOS',
      capturedText: const Value('void main() {}'),
    ));

    final last = await database.lastActivity();
    expect(last, isNotNull);
    expect(last!.appName, 'Code.exe');
    expect(last.capturedText, 'void main() {}');

    final recent = await database.watchRecentActivities().first;
    expect(recent, hasLength(1));
  });

  test('watchRecentActivities orders newest first', () async {
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'A',
      windowTitle: 'first',
      capturedAt: Value(DateTime.utc(2026, 1, 1)),
    ));
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'B',
      windowTitle: 'second',
      capturedAt: Value(DateTime.utc(2026, 1, 2)),
    ));

    final recent = await database.watchRecentActivities().first;
    expect(recent.map((a) => a.windowTitle), ['second', 'first']);
  });

  test('purgeActivitiesOlderThan deletes only stale rows', () async {
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'A',
      windowTitle: 'old',
      capturedAt: Value(DateTime.utc(2020, 1, 1)),
    ));
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'B',
      windowTitle: 'recent',
      capturedAt: Value(DateTime.utc(2026, 1, 1)),
    ));

    final deleted = await database.purgeActivitiesOlderThan(DateTime.utc(2025, 1, 1));
    expect(deleted, 1);

    final remaining = await database.watchRecentActivities().first;
    expect(remaining.map((a) => a.windowTitle), ['recent']);
  });
}
