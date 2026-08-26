import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:test/test.dart';

void main() {
  test('retention purges raw activity and derived summaries together',
      () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final memory = MemoryService(
      database: database,
      activities: SqliteActivityRepository(database),
      summaries: SqliteSummaryRepository(database),
    );
    final cutoff = DateTime.utc(2026, 8, 1);
    await memory.record(NewActivity(
      appName: 'old',
      windowTitle: 'old',
      capturedAt: cutoff.subtract(const Duration(days: 1)),
    ));
    await memory.record(NewActivity(
      appName: 'new',
      windowTitle: 'new',
      capturedAt: cutoff.add(const Duration(days: 1)),
    ));
    await memory.summaries.create(NewActivitySummary(
      kind: SummaryKind.periodic,
      periodStart: cutoff.subtract(const Duration(days: 2)),
      periodEnd: cutoff,
      content: 'old summary',
    ));
    await memory.summaries.create(NewActivitySummary(
      kind: SummaryKind.periodic,
      periodStart: cutoff,
      periodEnd: cutoff.add(const Duration(days: 1)),
      content: 'new summary',
    ));

    final removed = await memory.purgeOlderThan(cutoff);

    expect(removed.activities, 1);
    expect(removed.summaries, 1);
    expect((await memory.watchRecentActivities().first).single.appName, 'new');
    expect((await memory.watchRecentSummaries().first).single.content,
        'new summary');
  });
}
