import 'package:kangoos_core/src/database/database.dart';
import 'package:kangoos_core/src/database/tables/activity_summaries_table.dart';
import 'package:kangoos_core/src/infrastructure/sqlite/sqlite_episode_repository.dart';
import 'package:kangoos_core/src/infrastructure/sqlite/sqlite_persona_repository.dart';
import 'package:kangoos_core/src/infrastructure/sqlite/sqlite_summary_repository.dart';
import 'package:kangoos_core/src/memory/episode_repository.dart';
import 'package:kangoos_core/src/memory/memory_hierarchy_service.dart';
import 'package:kangoos_core/src/memory/persona_service.dart';
import 'package:kangoos_core/src/memory/summary_repository.dart';
import 'package:test/test.dart';

void main() {
  late KangoosDatabase database;
  late SqliteEpisodeRepository episodes;
  late SqliteSummaryRepository summaries;
  late SqlitePersonaRepository personas;
  late PersonaService service;

  setUp(() {
    database = KangoosDatabase.memory();
    episodes = SqliteEpisodeRepository(database);
    summaries = SqliteSummaryRepository(database);
    personas = SqlitePersonaRepository(database);
    service = PersonaService(repository: personas, summaries: summaries);
  });

  tearDown(() => database.close());

  test('generates only from automatic recurring durable memories', () async {
    await _seedRecurringMemories(episodes, summaries);
    await summaries.create(
      NewActivitySummary(
        kind: SummaryKind.durable,
        periodStart: DateTime.utc(2026, 8, 10),
        periodEnd: DateTime.utc(2026, 8, 10),
        content: 'Manual durable preference',
      ),
    );

    final persona = await service.generate();
    expect(persona, isNotNull);
    expect(persona!.content, contains('Dart'));
    expect(persona.content, isNot(contains('Rust')));
    expect(persona.content, isNot(contains('Manual durable preference')));
    expect(persona.sourceSummaryIds, hasLength(1));

    await service.generate();
    expect(await database.select(database.localPersonas).get(), hasLength(1));
  });

  test(
    'edits safely, toggles, deletes and enforces the content limit',
    () async {
      await _seedRecurringMemories(episodes, summaries);
      await service.generate();

      final edited = await service.edit('API_KEY=very-secret-value');
      expect(edited.content, 'API_KEY=[REDACTED]');
      expect(
        service.edit(List.filled(maxLocalPersonaCharacters + 1, 'x').join()),
        throwsArgumentError,
      );

      final disabled = await service.setEnabled(false);
      expect(disabled.enabled, isFalse);
      expect(await service.promptContent(), isNull);
      await service.setEnabled(true);
      expect(await service.promptContent(), 'API_KEY=[REDACTED]');

      expect(await service.delete(), 1);
      expect(await service.load(), isNull);
    },
  );

  test(
    'invalidates the persona when a source durable memory disappears',
    () async {
      await _seedRecurringMemories(episodes, summaries);
      final persona = await service.generate();
      final sourceId = persona!.sourceSummaryIds.single;

      await (database.delete(database.activitySummaries)
        ..where((row) => row.id.equals(sourceId))).go();

      expect(await service.load(), isNull);
      expect(await personas.load(), isNull);
    },
  );
}

Future<void> _seedRecurringMemories(
  EpisodeRepository episodes,
  SqliteSummaryRepository summaries,
) async {
  final monday = DateTime.utc(2026, 8, 10);
  await _episode(episodes, 'one', monday, const ['Dart']);
  await _episode(episodes, 'two', monday.add(const Duration(hours: 2)), const [
    'Dart',
  ]);
  await _episode(episodes, 'three', monday.add(const Duration(days: 1)), const [
    'Dart',
  ]);
  await _episode(
    episodes,
    'isolated',
    monday.add(const Duration(days: 2)),
    const ['Rust'],
  );
  await MemoryHierarchyService(
    episodes: episodes,
    summaries: summaries,
  ).compact(monday, monday.add(const Duration(days: 7)));
}

Future<void> _episode(
  EpisodeRepository repository,
  String sourceKey,
  DateTime startedAt,
  List<String> technologies,
) => repository.create(
  NewMemoryEpisode(
    sourceKey: sourceKey,
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(hours: 1)),
    title: sourceKey,
    summary: sourceKey,
    applications: const ['Code'],
    urls: const [],
    topics: const ['development'],
    entities: const [],
    technologies: technologies,
    sourceActivityIds: const [],
  ),
);
