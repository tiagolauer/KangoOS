import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_app/memory/memory_compaction_service.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';

void main() {
  test('compacts completed days in the configured lookback', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final episodes = SqliteEpisodeRepository(database);
    final monday = DateTime.utc(2026, 8, 10);
    await episodes.create(NewMemoryEpisode(
      sourceKey: 'completed-week',
      startedAt: monday.add(const Duration(hours: 9)),
      endedAt: monday.add(const Duration(hours: 10)),
      title: 'Completed work',
      summary: 'Completed the architecture pass',
      applications: const ['Code'],
      urls: const [],
      topics: const ['architecture'],
      entities: const [],
      sourceActivityIds: const [],
    ));
    final service = MemoryCompactionService(
      hierarchy: MemoryHierarchyService(
        episodes: episodes,
        summaries: SqliteSummaryRepository(database),
      ),
      now: () => DateTime.utc(2026, 8, 17, 12),
    );

    final report = await service.tick();

    expect(report?.sessions, 1);
    expect(report?.daily, 1);
    expect(report?.weekly, 1);
  });
}
