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

  test('summariesBetween returns only summaries overlapping the range', () async {
    await database.insertActivitySummary(ActivitySummariesCompanion.insert(
      kind: SummaryKind.periodic,
      periodStart: DateTime.utc(2026, 1, 1),
      periodEnd: DateTime.utc(2026, 1, 1, 1),
      content: 'in range',
    ));
    await database.insertActivitySummary(ActivitySummariesCompanion.insert(
      kind: SummaryKind.periodic,
      periodStart: DateTime.utc(2026, 1, 5),
      periodEnd: DateTime.utc(2026, 1, 5, 1),
      content: 'out of range',
    ));

    final results = await database.summariesBetween(
        DateTime.utc(2025, 12, 31), DateTime.utc(2026, 1, 2));

    expect(results, hasLength(1));
    expect(results.single.content, 'in range');
  });

  test('getSummaryById returns the matching row or null', () async {
    expect(await database.getSummaryById(999), isNull);

    final id = await database.insertActivitySummary(ActivitySummariesCompanion.insert(
      kind: SummaryKind.manual,
      periodStart: DateTime.utc(2026, 1, 1),
      periodEnd: DateTime.utc(2026, 1, 1),
      content: 'a note',
    ));

    final fetched = await database.getSummaryById(id);
    expect(fetched?.content, 'a note');
  });
}
