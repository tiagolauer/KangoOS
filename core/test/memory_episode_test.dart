import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:test/test.dart';

class _MemoryEmbeddingProvider implements EmbeddingProvider {
  @override
  String get id => 'memory-test-model';

  @override
  Future<List<double>> embed(String text) async =>
      text.toLowerCase().contains('jwt') ? [1, 0] : [0, 1];
}

void main() {
  test('forms deduplicated episodes and retrieves them with hybrid search',
      () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final activities = SqliteActivityRepository(database);
    final episodes = SqliteEpisodeRepository(database);
    final provider = _MemoryEmbeddingProvider();
    final start = DateTime.utc(2026, 8, 24, 14);
    await activities.create(NewActivity(
      appName: 'VS Code',
      windowTitle: 'auth_service.dart',
      capturedText: 'Implement JWT refresh tokens',
      capturedAt: start,
    ));
    await activities.create(NewActivity(
      appName: 'Chrome',
      windowTitle: 'JWT documentation',
      capturedUrl: 'https://example.com/jwt',
      capturedAt: start.add(const Duration(minutes: 10)),
    ));
    await activities.create(NewActivity(
      appName: 'Terminal',
      windowTitle: 'unrelated deploy',
      capturedAt: start.add(const Duration(hours: 1)),
    ));
    final formation = MemoryFormationService(
      activities: activities,
      episodes: episodes,
      embeddingProvider: provider,
    );

    final first = await formation.formBetween(
      start.subtract(const Duration(minutes: 1)),
      start.add(const Duration(hours: 2)),
    );
    final second = await formation.formBetween(
      start.subtract(const Duration(minutes: 1)),
      start.add(const Duration(hours: 2)),
    );
    final search = await MemoryQueryEngine(
      episodes: episodes,
      embeddingProvider: provider,
    ).search('JWT', reference: start.add(const Duration(days: 1)));

    expect(first.created, 2);
    expect(first.indexed, 2);
    expect(second.created, 0);
    expect(search.matches, isNotEmpty);
    expect(search.matches.first.episode.summary, contains('refresh tokens'));
    expect(search.matches.first.lexical, isTrue);
    expect(search.matches.first.semantic, isTrue);
  });

  test('rule-based temporal parser understands Portuguese day periods',
      () async {
    final parsed = await const RuleBasedTemporalParser().parse(
      'o que fiz ontem à tarde?',
      DateTime(2026, 8, 25, 20),
    );

    expect(parsed.start, DateTime(2026, 8, 24, 12));
    expect(parsed.end, DateTime(2026, 8, 24, 18));
    expect(parsed.fuzzy, isTrue);
  });

  test('temporal parser handles ranges, recency, fuzzy dates and timezones',
      () {
    const parser = RuleBasedTemporalParser();
    final reference = DateTime(2026, 8, 25, 20);

    final weekdays = parser.parseSync('entre segunda e quarta', reference);
    expect(weekdays.start, DateTime(2026, 8, 24));
    expect(weekdays.end, DateTime(2026, 8, 27));

    final recent = parser.parseSync('ultimos 3 dias', reference);
    expect(recent.start, DateTime(2026, 8, 23));
    expect(recent.end, reference);

    final dayBefore = parser.parseSync('anteontem', reference);
    expect(dayBefore.start, DateTime(2026, 8, 23));
    expect(dayBefore.end, DateTime(2026, 8, 24));

    final fuzzy = parser.parseSync('fim de julho', reference);
    expect(fuzzy.start, DateTime(2026, 7, 25));
    expect(fuzzy.end, DateTime(2026, 8));
    expect(fuzzy.fuzzy, isTrue);
    expect(fuzzy.confidence, 0.8);

    final zoned = parser.parseSync(
      'ontem BRT',
      DateTime.utc(2026, 8, 25, 12),
    );
    expect(zoned.start, DateTime.utc(2026, 8, 24, 3));
    expect(zoned.end, DateTime.utc(2026, 8, 25, 3));
    expect(zoned.timezoneOffset, const Duration(hours: -3));

    final invalid = parser.parseSync(
      'ultimos 999999999999999999999 dias UTC+99',
      reference,
    );
    expect(invalid.hasRange, isFalse);
    expect(invalid.timezoneOffset, isNull);
  });
}
