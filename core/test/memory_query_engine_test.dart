import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;
import 'package:test/test.dart';

class _CorpusEmbeddingProvider implements EmbeddingProvider {
  @override
  String get id => 'm4-corpus-v1';

  @override
  Future<List<double>> embed(String text) async {
    final vector = List<double>.filled(24, 0);
    for (final rune in text.toLowerCase().runes) {
      vector[rune % vector.length]++;
    }
    return vector;
  }
}

void main() {
  test('indexes and retrieves all memory sources with RRF evidence', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final activities = SqliteActivityRepository(database);
    final episodes = SqliteEpisodeRepository(database);
    final summaries = SqliteSummaryRepository(database);
    final conversations = SqliteConversationRepository(database);
    final snippets = SqliteSnippetRepository(database);
    final provider = _CorpusEmbeddingProvider();
    final engine = MemoryQueryEngine(
      episodes: episodes,
      summaries: summaries,
      conversations: conversations,
      snippets: snippets,
      activities: activities,
      embeddingProvider: provider,
    );
    final now = DateTime.utc(2026, 8, 26, 12);
    final activityId = await activities.create(
      NewActivity(
        appName: 'Code',
        windowTitle: 'Kango architecture',
        capturedAt: now,
      ),
    );
    await episodes.create(
      NewMemoryEpisode(
        sourceKey: 'm4-unified',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 30)),
        title: 'Kango episode',
        summary: 'Kango unified retrieval episode',
        applications: const ['Code'],
        urls: const [],
        topics: const ['Kango'],
        entities: const ['project:OpenKango/KangoOS'],
        sourceActivityIds: [activityId],
      ),
    );
    await summaries.create(
      NewActivitySummary(
        kind: SummaryKind.daily,
        periodStart: now,
        periodEnd: now.add(const Duration(hours: 1)),
        content: 'Kango daily summary',
      ),
    );
    await summaries.create(
      NewActivitySummary(
        kind: SummaryKind.durable,
        periodStart: now,
        periodEnd: now,
        content: 'Kango durable memory',
      ),
    );
    final conversationId = await conversations.create();
    await conversations.appendMessage(
      conversationId,
      LlmRole.user,
      'Kango conversation message',
    );
    await snippets.create(
      NewSnippet(
        title: 'Kango snippet',
        content: 'Kango reusable command',
        tags: const ['project:OpenKango/KangoOS'],
        createdAt: now,
        updatedAt: now,
      ),
    );

    final firstIndex = await engine.indexPending();
    final secondIndex = await engine.indexPending();
    final result = await engine.search('Kango', reference: now);

    expect(firstIndex.indexed, 5);
    expect(firstIndex.failures, isEmpty);
    expect(secondIndex.indexed, 0);
    expect(
      result.evidence.map((item) => item.source).toSet(),
      containsAll(MemoryEvidenceSource.values),
    );
    expect(result.evidence.every((item) => item.score > 0), isTrue);
    expect(
      result.evidence.every((item) => item.matchReasons.isNotEmpty),
      isTrue,
    );
    expect(
      result.evidence.any((item) => item.matchReasons.length >= 2),
      isTrue,
    );
  });

  test(
    'filters by source, application, modality, project and interval',
    () async {
      final database = KangoosDatabase.memory();
      addTearDown(database.close);
      final activities = SqliteActivityRepository(database);
      final episodes = SqliteEpisodeRepository(database);
      final now = DateTime.utc(2026, 8, 26, 12);
      final teamsActivity = await activities.create(
        NewActivity(
          appName: 'Teams',
          windowTitle: 'Apollo review',
          capturedAudioText: 'Apollo architecture accepted',
          capturedAt: now,
        ),
      );
      await episodes.create(
        NewMemoryEpisode(
          sourceKey: 'apollo-teams',
          startedAt: now,
          endedAt: now.add(const Duration(minutes: 30)),
          title: 'Apollo review',
          summary: 'Apollo architecture accepted',
          applications: const ['Teams'],
          urls: const [],
          topics: const ['Apollo'],
          entities: const ['project:OpenKango/KangoOS'],
          sourceActivityIds: [teamsActivity],
        ),
      );
      await episodes.create(
        NewMemoryEpisode(
          sourceKey: 'apollo-code',
          startedAt: now.subtract(const Duration(days: 2)),
          endedAt: now.subtract(const Duration(days: 2, minutes: -30)),
          title: 'Apollo code',
          summary: 'Apollo implementation',
          applications: const ['Code'],
          urls: const [],
          topics: const ['Apollo'],
          entities: const ['project:Other/Project'],
          sourceActivityIds: const [],
        ),
      );
      final engine = MemoryQueryEngine(
        episodes: episodes,
        activities: activities,
        embeddingProvider: _CorpusEmbeddingProvider(),
      );
      await engine.indexPending();

      final result = await engine.search(
        'Apollo',
        reference: now,
        mode: MemorySearchMode.semantic,
        filters: MemorySearchFilters(
          sources: const {MemoryEvidenceSource.episode},
          applications: const {'teams'},
          modalities: const {MemoryModality.audio},
          projects: const {'openkango/kangoos'},
          start: now.subtract(const Duration(hours: 1)),
          end: now.add(const Duration(hours: 1)),
        ),
      );

      expect(result.evidence, hasLength(1));
      expect(result.evidence.single.id, 'episode:1');
      expect(result.evidence.single.applications, contains('Teams'));
      expect(result.evidence.single.modalities, contains(MemoryModality.audio));
    },
  );

  test(
    'resolves event-relative temporal queries from indexed evidence',
    () async {
      final database = KangoosDatabase.memory();
      addTearDown(database.close);
      final episodes = SqliteEpisodeRepository(database);
      final day = DateTime.utc(2026, 8, 26);
      await episodes.create(
        NewMemoryEpisode(
          sourceKey: 'preparation',
          startedAt: day.add(const Duration(hours: 8)),
          endedAt: day.add(const Duration(hours: 9)),
          title: 'Preparação',
          summary: 'Revisei o currículo e o projeto Apollo',
          applications: const ['Code'],
          urls: const [],
          topics: const ['currículo'],
          entities: const [],
          sourceActivityIds: const [],
        ),
      );
      await episodes.create(
        NewMemoryEpisode(
          sourceKey: 'interview',
          startedAt: day.add(const Duration(hours: 10)),
          endedAt: day.add(const Duration(hours: 11)),
          title: 'Entrevista',
          summary: 'Entrevista do projeto Apollo',
          applications: const ['Teams'],
          urls: const [],
          topics: const ['entrevista'],
          entities: const [],
          sourceActivityIds: const [],
        ),
      );
      final engine = MemoryQueryEngine(episodes: episodes);

      final result = await engine.search(
        'o que fiz antes da entrevista',
        reference: day.add(const Duration(hours: 18)),
        mode: MemorySearchMode.temporal,
      );

      expect(result.temporal?.relation, TemporalRelation.before);
      expect(result.temporal?.anchor, 'entrevista');
      expect(result.evidence.map((item) => item.id), ['episode:1']);
      expect(
        result.evidence.single.matchReasons.single,
        contains('Correspondência temporal'),
      );
    },
  );

  test(
    'migrates v20 summaries and conversations into the unified index',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'kangoos_m4_migration',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/legacy.db');
      final initial = KangoosDatabase.native(file);
      final summaryId = await initial.insertActivitySummary(
        ActivitySummariesCompanion.insert(
          kind: SummaryKind.daily,
          periodStart: DateTime.utc(2026, 8, 25),
          periodEnd: DateTime.utc(2026, 8, 26),
          content: 'Preserve Aurora summary',
        ),
      );
      final conversationId = await initial.createConversation();
      final messageId = await initial.appendMessage(
        conversationId,
        LlmRole.user,
        'Preserve Aurora conversation',
      );
      await initial.close();

      final legacy = sqlite3.open(file.path);
      for (final table in ['activity_summaries', 'conversation_messages']) {
        legacy.execute('ALTER TABLE $table DROP COLUMN embedding_provider_id;');
        legacy.execute('ALTER TABLE $table DROP COLUMN embedding;');
      }
      legacy.execute('PRAGMA user_version = 20;');
      legacy.dispose();

      final migrated = KangoosDatabase.native(file);
      addTearDown(migrated.close);
      final summaries = SqliteSummaryRepository(migrated);
      final conversations = SqliteConversationRepository(migrated);

      expect((await summaries.searchKeyword('Aurora')).single.id, summaryId);
      expect((await conversations.search('Aurora')).single.id, messageId);
      expect(await summaries.pendingEmbedding('m4'), hasLength(1));
      expect(await conversations.pendingEmbedding('m4'), hasLength(1));
    },
  );
}
