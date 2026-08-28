import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:test/test.dart';

void main() {
  test('compacts episodes into idempotent session, daily and weekly memories',
      () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final episodes = SqliteEpisodeRepository(database);
    final summaries = SqliteSummaryRepository(database);
    final monday = DateTime.utc(2026, 8, 10);
    await _addEpisode(episodes, 'one', monday.add(const Duration(hours: 9)));
    await _addEpisode(episodes, 'two', monday.add(const Duration(hours: 11)));
    await _addEpisode(
      episodes,
      'three',
      monday.add(const Duration(days: 1, hours: 9)),
    );
    final hierarchy = MemoryHierarchyService(
      episodes: episodes,
      summaries: summaries,
    );

    final first = await hierarchy.compact(
      monday,
      monday.add(const Duration(days: 7)),
    );
    final second = await hierarchy.compact(
      monday,
      monday.add(const Duration(days: 7)),
    );
    final stored = await summaries.all();

    expect(first.sessions, 2);
    expect(first.daily, 2);
    expect(first.weekly, 1);
    expect(second.created, 0);
    expect(
        stored.where((item) => item.kind == SummaryKind.session), hasLength(2));
    expect(
        stored.where((item) => item.kind == SummaryKind.daily), hasLength(2));
    expect(
        stored.where((item) => item.kind == SummaryKind.weekly), hasLength(1));

    final durable = await MemoryService(
      database: database,
      activities: SqliteActivityRepository(database),
      summaries: summaries,
    ).remember('Prefer local-first storage');
    expect(durable.kind, SummaryKind.durable);
  });

  test('promotes only recurring evidence to an automatic durable memory',
      () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final episodes = SqliteEpisodeRepository(database);
    final summaries = SqliteSummaryRepository(database);
    final monday = DateTime.utc(2026, 8, 10);
    await _addEpisode(
      episodes,
      'one',
      monday.add(const Duration(hours: 9)),
      technologies: const ['Dart'],
    );
    await _addEpisode(
      episodes,
      'two',
      monday.add(const Duration(hours: 11)),
      technologies: const ['Dart'],
    );
    await _addEpisode(
      episodes,
      'three',
      monday.add(const Duration(days: 1, hours: 9)),
      technologies: const ['Dart'],
    );
    await _addEpisode(
      episodes,
      'isolated',
      monday.add(const Duration(days: 2, hours: 9)),
      technologies: const ['Rust'],
    );
    final hierarchy = MemoryHierarchyService(
      episodes: episodes,
      summaries: summaries,
    );

    final first = await hierarchy.compact(
      monday,
      monday.add(const Duration(days: 7)),
    );
    final second = await hierarchy.compact(
      monday,
      monday.add(const Duration(days: 7)),
    );
    final durable = (await summaries.all())
        .where((summary) => summary.kind == SummaryKind.durable)
        .single;

    expect(first.durable, 1);
    expect(second.durable, 0);
    expect(durable.content, contains('Memória recorrente: Dart'));
    expect(durable.content, contains('episódio #'));
    expect(durable.content, isNot(contains('Rust')));
  });
}

Future<void> _addEpisode(
  EpisodeRepository episodes,
  String key,
  DateTime start,
  {List<String> technologies = const []}
) async {
  await episodes.create(NewMemoryEpisode(
    sourceKey: key,
    startedAt: start,
    endedAt: start.add(const Duration(hours: 1)),
    title: 'Episode $key',
    summary: 'Summary $key',
    applications: const ['Code'],
    urls: const [],
    topics: const ['architecture'],
    entities: const [],
    technologies: technologies,
    sourceActivityIds: const [],
  ));
}
