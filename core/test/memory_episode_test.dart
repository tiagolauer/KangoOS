import 'dart:convert';
import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:test/test.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

class _MemoryEmbeddingProvider implements EmbeddingProvider {
  @override
  String get id => 'memory-test-model';

  @override
  Future<List<double>> embed(String text) async =>
      text.toLowerCase().contains('jwt') ? [1, 0] : [0, 1];
}

class _JsonLlmProvider extends LlmProvider {
  _JsonLlmProvider(this.payload);

  final Map<String, Object?> payload;
  final prompts = <List<LlmMessage>>[];

  @override
  String get id => 'json-test';

  @override
  Stream<String> chat(List<LlmMessage> messages) {
    prompts.add(messages);
    return Stream.value(jsonEncode(payload));
  }
}

class _FailingMemoryLlmProvider extends LlmProvider {
  @override
  String get id => 'failing-memory';

  @override
  Stream<String> chat(List<LlmMessage> messages) =>
      Stream.error(StateError('LM Studio unavailable'));
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
    expect((await episodes.recent()).first.contentHash, isNotEmpty);
    expect(
      (await episodes.recent()).first.formationVersion,
      currentMemoryFormationVersion,
    );
    expect(search.matches, isNotEmpty);
    expect(search.matches.first.episode.summary, contains('refresh tokens'));
    expect(search.matches.first.lexical, isTrue);
    expect(search.matches.first.semantic, isTrue);
  });

  test('enriches locally once and reprocesses only when the model changes',
      () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final activities = SqliteActivityRepository(database);
    final episodes = SqliteEpisodeRepository(database);
    final start = DateTime.utc(2026, 8, 24, 14);
    await activities.create(NewActivity(
      appName: 'VS Code',
      windowTitle: 'auth_service.dart',
      capturedText: 'Decidimos usar Dart. TODO: validar o refresh token.',
      capturedUrl: 'https://github.com/kangoos/auth',
      capturedAt: start,
    ));
    final provider = _JsonLlmProvider({
      'summary': 'A equipe definiu a validação do refresh token.',
      'confidence': 0.92,
      'decisions': ['Usar Dart no serviço de autenticação'],
      'actionItems': ['Validar o refresh token'],
      'technologies': ['Dart', 'JWT'],
      'people': ['Tiago'],
      'projects': ['KangoOS'],
      'files': ['auth_service.dart'],
      'relations': ['KangoOS usa JWT'],
    });
    final formation = MemoryFormationService(
      activities: activities,
      episodes: episodes,
    );
    final first = await formation.formBetween(
      start,
      start.add(const Duration(hours: 1)),
      enricher: MemoryEpisodeEnricher(
        provider: provider,
        modelId: 'lm-studio|qwen|1',
      ),
    );
    final second = await formation.formBetween(
      start,
      start.add(const Duration(hours: 1)),
      enricher: MemoryEpisodeEnricher(
        provider: provider,
        modelId: 'lm-studio|qwen|1',
      ),
    );
    final replacementProvider = _JsonLlmProvider(provider.payload);
    final third = await formation.formBetween(
      start,
      start.add(const Duration(hours: 1)),
      enricher: MemoryEpisodeEnricher(
        provider: replacementProvider,
        modelId: 'lm-studio|qwen|2',
      ),
    );
    final stored = (await episodes.recent()).single;
    final decisionMatches = await episodes.searchKeyword('JWT');
    final projectMatches = await episodes.searchKeyword('KangoOS');

    expect(first.created, 1);
    expect(first.enriched, 1);
    expect(second.created, 0);
    expect(second.updated, 0);
    expect(second.enriched, 0);
    expect(provider.prompts, hasLength(1));
    expect(third.updated, 1);
    expect(third.enriched, 1);
    expect(stored.formationStatus, MemoryFormationStatus.enriched);
    expect(stored.formationModelId, 'lm-studio|qwen|2');
    expect(stored.confidence, 0.92);
    expect(stored.decisions, contains('Usar Dart no serviço de autenticação'));
    expect(stored.actionItems, contains('Validar o refresh token'));
    expect(stored.technologies, containsAll(['Dart', 'JWT']));
    expect(stored.entities, containsAll([
      'person:Tiago',
      'project:KangoOS',
      'file:auth_service.dart',
      'relation:KangoOS usa JWT',
    ]));
    expect(decisionMatches.single.id, stored.id);
    expect(projectMatches.single.id, stored.id);
    expect(stored.startedAt.isAtSameMomentAs(start), isTrue);
    expect(stored.sourceActivityIds, isNotEmpty);
    expect(provider.prompts.single.first.content, contains('português do Brasil'));
  });

  test('keeps deterministic memory when local enrichment fails', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final activities = SqliteActivityRepository(database);
    final episodes = SqliteEpisodeRepository(database);
    final start = DateTime.utc(2026, 8, 24, 14);
    await activities.create(NewActivity(
      appName: 'Terminal',
      windowTitle: 'deploy KangoOS',
      capturedText: 'Decidimos publicar na sexta-feira.',
      capturedAt: start,
    ));

    final report = await MemoryFormationService(
      activities: activities,
      episodes: episodes,
    ).formBetween(
      start,
      start.add(const Duration(hours: 1)),
      enricher: MemoryEpisodeEnricher(
        provider: _FailingMemoryLlmProvider(),
        modelId: 'lm-studio|offline',
      ),
    );
    final stored = (await episodes.recent()).single;

    expect(report.created, 1);
    expect(report.enrichmentFailures, hasLength(1));
    expect(stored.formationStatus, MemoryFormationStatus.failed);
    expect(stored.summary, contains('publicar na sexta-feira'));
    expect(stored.decisions, contains('Decidimos publicar na sexta-feira.'));
  });

  test('rebuilds an episode when its source content hash changes', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final activities = SqliteActivityRepository(database);
    final episodes = SqliteEpisodeRepository(database);
    final start = DateTime.utc(2026, 8, 24, 14);
    final activityId = await activities.create(NewActivity(
      appName: 'Code',
      windowTitle: 'updated.dart',
      capturedText: 'Updated source content',
      capturedAt: start,
    ));
    await episodes.create(NewMemoryEpisode(
      sourceKey: '$activityId:$activityId',
      startedAt: start,
      endedAt: start,
      title: 'stale.dart',
      summary: 'Stale source content',
      applications: const ['Code'],
      urls: const [],
      topics: const [],
      entities: const [],
      sourceActivityIds: [activityId],
      contentHash: 'stale',
    ));

    final report = await MemoryFormationService(
      activities: activities,
      episodes: episodes,
    ).formBetween(start, start.add(const Duration(hours: 1)));
    final stored = (await episodes.recent()).single;

    expect(report.updated, 1);
    expect(stored.contentHash, isNot('stale'));
    expect(stored.summary, contains('Updated source content'));
  });

  test('backfill advances in resumable idempotent batches', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final activities = SqliteActivityRepository(database);
    final episodes = SqliteEpisodeRepository(database);
    final start = DateTime.utc(2026, 8, 20);
    await activities.create(NewActivity(
      appName: 'Code',
      windowTitle: 'day one',
      capturedAt: start.add(const Duration(hours: 10)),
    ));
    await activities.create(NewActivity(
      appName: 'Code',
      windowTitle: 'day two',
      capturedAt: start.add(const Duration(days: 1, hours: 10)),
    ));
    final formation = MemoryFormationService(
      activities: activities,
      episodes: episodes,
    );

    final first = await formation.backfillBatch(
      start: start,
      end: start.add(const Duration(days: 2)),
      batchSpan: const Duration(days: 1),
    );
    final resumed = await formation.backfillBatch(
      start: start,
      end: start.add(const Duration(days: 2)),
      cursor: first.cursor,
      batchSpan: const Duration(days: 1),
    );
    final retried = await formation.backfillBatch(
      start: start,
      end: start.add(const Duration(days: 2)),
      batchSpan: const Duration(days: 1),
    );

    expect(first.completed, isFalse);
    expect(first.report.created, 1);
    expect(resumed.completed, isTrue);
    expect(resumed.report.created, 1);
    expect(retried.report.created, 0);
    expect(await episodes.recent(), hasLength(2));
  });

  test('migrates v19 episodes and rebuilds searchable formation fields',
      () async {
    final directory =
        Directory.systemTemp.createTempSync('kangoos_m3_migration');
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File('${directory.path}/legacy.db');
    final initial = KangoosDatabase.native(file);
    final initialEpisodes = SqliteEpisodeRepository(initial);
    await initialEpisodes.create(NewMemoryEpisode(
      sourceKey: 'legacy',
      startedAt: DateTime.utc(2026, 8, 20, 10),
      endedAt: DateTime.utc(2026, 8, 20, 11),
      title: 'Legacy episode',
      summary: 'Preserve legacy searchable memory',
      applications: const ['Code'],
      urls: const [],
      topics: const ['legacy'],
      entities: const [],
      sourceActivityIds: const [1],
    ));
    await initial.close();

    final legacy = sqlite3.open(file.path);
    for (final trigger in [
      'memory_episodes_fts_ai',
      'memory_episodes_fts_ad',
      'memory_episodes_fts_au',
    ]) {
      legacy.execute('DROP TRIGGER IF EXISTS $trigger;');
    }
    legacy.execute('DROP TABLE IF EXISTS memory_episodes_fts;');
    for (final column in [
      'formation_model_id',
      'technologies',
      'action_items',
      'decisions',
      'confidence',
      'formation_status',
      'content_hash',
      'formation_version',
    ]) {
      legacy.execute('ALTER TABLE memory_episodes DROP COLUMN $column;');
    }
    legacy.execute('PRAGMA user_version = 19;');
    legacy.dispose();

    final migrated = KangoosDatabase.native(file);
    addTearDown(migrated.close);
    final episodes = SqliteEpisodeRepository(migrated);
    final stored = (await episodes.recent()).single;
    final found = await episodes.searchKeyword('legacy');

    expect(stored.formationVersion, 1);
    expect(stored.formationStatus, MemoryFormationStatus.deterministic);
    expect(stored.decisions, isEmpty);
    expect(found.single.id, stored.id);
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
