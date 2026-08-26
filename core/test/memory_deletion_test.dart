import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:test/test.dart';

class _EmbeddingProvider implements EmbeddingProvider {
  @override
  String get id => 'test-embedding';

  @override
  Future<List<double>> embed(String text) async => const [1, 0, 0];
}

class _LlmProvider implements LlmProvider {
  List<LlmMessage> messages = const [];

  @override
  String get id => 'test-llm';

  @override
  Stream<String> chat(List<LlmMessage> messages) {
    this.messages = messages;
    return Stream.value('ok');
  }
}

void main() {
  late KangoosDatabase database;
  late SqliteEpisodeRepository episodes;
  late MemoryService memory;
  late SnippetService snippets;

  setUp(() {
    database = KangoosDatabase.memory();
    episodes = SqliteEpisodeRepository(database);
    final embeddingProvider = _EmbeddingProvider();
    final snippetRepository = SqliteSnippetRepository(database);
    snippets = SnippetService(
      repository: snippetRepository,
      semanticSearch: SemanticSearch(
        repository: snippetRepository,
        embeddingProvider: embeddingProvider,
      ),
    );
    memory = MemoryService(
      database: database,
      activities: SqliteActivityRepository(database),
      summaries: SqliteSummaryRepository(database),
      episodes: episodes,
      queryEngine: MemoryQueryEngine(
        episodes: episodes,
        embeddingProvider: embeddingProvider,
      ),
    );
  });

  tearDown(() => database.close());

  test(
    'deletes one application modality and every contaminated derivative',
    () async {
      final start = DateTime(2026, 8, 25);
      final end = start.add(const Duration(days: 1));
      final slackActivityId = await database.logActivity(
        ActivitiesCompanion.insert(
          appName: 'Slack',
          windowTitle: 'Team',
          capturedClipboard: const Value('private-fragment-71'),
          capturedScreenText: const Value('public Slack context'),
          capturedAt: Value(start.add(const Duration(hours: 10))),
        ),
      );
      await database.logActivity(
        ActivitiesCompanion.insert(
          appName: 'Editor',
          windowTitle: 'Notes',
          capturedClipboard: const Value('private-fragment-71'),
          capturedAt: Value(start.add(const Duration(hours: 11))),
        ),
      );
      final episodeId = await episodes.create(
        NewMemoryEpisode(
          sourceKey: 'slack-private-fragment',
          startedAt: start.add(const Duration(hours: 10)),
          endedAt: start.add(const Duration(hours: 10, minutes: 1)),
          title: 'Slack clipboard',
          summary: 'private-fragment-71',
          applications: const ['Slack'],
          urls: const [],
          topics: const ['private-fragment-71'],
          entities: const [],
          sourceActivityIds: [slackActivityId],
        ),
      );
      await episodes.setEmbedding(episodeId, const [1, 0, 0], 'test-embedding');
      await database.insertActivitySummary(
        ActivitySummariesCompanion.insert(
          kind: SummaryKind.periodic,
          periodStart: start,
          periodEnd: end,
          content: 'Automatic private-fragment-71 recap',
        ),
      );
      for (final kind in const [SummaryKind.manual, SummaryKind.durable]) {
        await database.insertActivitySummary(
          ActivitySummariesCompanion.insert(
            kind: kind,
            periodStart: start,
            periodEnd: end,
            content: '${kind.name} kept',
          ),
        );
      }
      await database.insertActivitySummary(
        ActivitySummariesCompanion.insert(
          kind: SummaryKind.durable,
          periodStart: start,
          periodEnd: end,
          content: '[auto-durable:technology:dart]\n'
              'Memória recorrente: Dart\n'
              'Evidências:\n- episódio #$episodeId',
        ),
      );

      final filter = MemoryDeletionFilter(
        start: start,
        end: end,
        applications: const {'Slack'},
        modalities: const {MemoryModality.clipboard},
      );
      final preview = await memory.previewDeletion(filter);
      expect(preview.activities, 1);
      expect(preview.episodes, 1);
      expect(preview.summaries, 2);
      expect(preview.embeddings, 1);

      final deleted = await memory.delete(filter);
      expect(deleted.total, 4);
      final activities = await database.allActivities();
      expect(activities, hasLength(2));
      expect(
        activities
            .singleWhere((row) => row.id == slackActivityId)
            .capturedClipboard,
        isNull,
      );
      expect(
        activities
            .singleWhere((row) => row.appName == 'Editor')
            .capturedClipboard,
        'private-fragment-71',
      );
      expect(
        await database.searchActivities('private-fragment-71'),
        hasLength(1),
      );
      expect(await episodes.searchKeyword('private-fragment-71'), isEmpty);
      expect(
        (await memory.searchEpisodes(
          'private-fragment-71',
          mode: MemorySearchMode.semantic,
        )).matches,
        isEmpty,
      );
      expect(
        (await database.allSummaries()).map((summary) => summary.kind),
        containsAll([SummaryKind.manual, SummaryKind.durable]),
      );
      expect(
        (await database.allSummaries())
            .where((summary) => summary.kind == SummaryKind.durable)
            .single
            .content,
        isNot(startsWith(automaticDurableMemoryPrefix)),
      );

      final llm = _LlmProvider();
      await RagChat(snippets: snippets, memory: memory)
          .reply(
            provider: llm,
            history: const [],
            userMessage: 'private-fragment-71',
          )
          .drain<void>();
      expect(
        llm.messages.map((message) => message.content).join('\n'),
        isNot(contains('Automatic private-fragment-71 recap')),
      );

      final mcp = KangoMcpServer(snippets: snippets, memory: memory);
      final response = await mcp.callTool('search_memories', {
        'query': 'private-fragment-71',
      });
      expect(jsonEncode(response), isNot(contains('Slack clipboard')));

      final repeated = await memory.delete(filter);
      expect(repeated.total, 0);
    },
  );

  test(
    'rolls the full deletion back when a derived delete is interrupted',
    () async {
      final capturedAt = DateTime(2026, 8, 25, 10);
      final activityId = await database.logActivity(
        ActivitiesCompanion.insert(
          appName: 'Slack',
          windowTitle: 'Team',
          capturedClipboard: const Value('rollback-fragment-92'),
          capturedAt: Value(capturedAt),
        ),
      );
      await episodes.create(
        NewMemoryEpisode(
          sourceKey: 'rollback-episode',
          startedAt: capturedAt,
          endedAt: capturedAt.add(const Duration(minutes: 1)),
          title: 'Rollback',
          summary: 'rollback-fragment-92',
          applications: const ['Slack'],
          urls: const [],
          topics: const [],
          entities: const [],
          sourceActivityIds: [activityId],
        ),
      );
      await database.customStatement('''
CREATE TRIGGER interrupt_memory_deletion
BEFORE DELETE ON memory_episodes
BEGIN
  SELECT RAISE(ABORT, 'simulated interruption');
END;
''');

      await expectLater(
        memory.delete(
          MemoryDeletionFilter(
            start: DateTime(2026, 8, 25),
            end: DateTime(2026, 8, 26),
            applications: const {'Slack'},
            modalities: const {MemoryModality.clipboard},
          ),
        ),
        throwsA(anything),
      );

      expect(
        (await database.allActivities()).single.capturedClipboard,
        'rollback-fragment-92',
      );
      expect(
        await database.searchActivities('rollback-fragment-92'),
        hasLength(1),
      );
      expect(
        await episodes.searchKeyword('rollback-fragment-92'),
        hasLength(1),
      );
    },
  );

  test(
    'clear removes orphan derivatives but preserves durable memory',
    () async {
      final at = DateTime(2026, 8, 25, 10);
      await episodes.create(
        NewMemoryEpisode(
          sourceKey: 'legacy-orphan',
          startedAt: at,
          endedAt: at.add(const Duration(minutes: 1)),
          title: 'Legacy orphan',
          summary: 'orphan-fragment',
          applications: const ['Legacy'],
          urls: const [],
          topics: const [],
          entities: const [],
          sourceActivityIds: const [],
        ),
      );
      await memory.remember('keep-durable', at: at);

      final result = await memory.clear();

      expect(result.episodes, 1);
      expect(await episodes.recent(), isEmpty);
      expect((await database.allSummaries()).single.content, 'keep-durable');
    },
  );

  test('deleting one activity does not clear unrelated derivatives', () async {
    final firstAt = DateTime(2026, 8, 25, 10);
    final secondAt = DateTime(2026, 8, 25, 15);
    final firstId = await database.logActivity(
      ActivitiesCompanion.insert(
        appName: 'First',
        windowTitle: 'First',
        capturedAt: Value(firstAt),
      ),
    );
    final secondId = await database.logActivity(
      ActivitiesCompanion.insert(
        appName: 'Second',
        windowTitle: 'Second',
        capturedAt: Value(secondAt),
      ),
    );
    for (final entry in [(firstId, firstAt), (secondId, secondAt)]) {
      await episodes.create(
        NewMemoryEpisode(
          sourceKey: 'source-${entry.$1}',
          startedAt: entry.$2,
          endedAt: entry.$2.add(const Duration(minutes: 1)),
          title: 'Episode ${entry.$1}',
          summary: 'summary',
          applications: const [],
          urls: const [],
          topics: const [],
          entities: const [],
          sourceActivityIds: [entry.$1],
        ),
      );
      await database.insertActivitySummary(
        ActivitySummariesCompanion.insert(
          kind: SummaryKind.periodic,
          periodStart: entry.$2,
          periodEnd: entry.$2.add(const Duration(hours: 1)),
          content: 'Summary ${entry.$1}',
        ),
      );
    }

    expect(await memory.deleteActivity(firstId), 1);

    expect((await database.allActivities()).single.id, secondId);
    expect((await episodes.recent()).single.sourceActivityIds, [secondId]);
    expect((await database.allSummaries()).single.content, 'Summary $secondId');
  });
}
