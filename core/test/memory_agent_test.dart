import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:test/test.dart';

void main() {
  test(
    'investigation reflects across memory sources and DeepStudy cites them',
    () async {
      final database = KangoosDatabase.memory();
      addTearDown(database.close);
      final snippetRepository = SqliteSnippetRepository(database);
      final snippets = SnippetService(repository: snippetRepository);
      final conversations = SqliteConversationRepository(database);
      final episodes = SqliteEpisodeRepository(database);
      final activities = SqliteActivityRepository(database);
      final summaries = SqliteSummaryRepository(database);
      final memory = MemoryService(
        database: database,
        activities: activities,
        summaries: summaries,
        episodes: episodes,
        queryEngine: MemoryQueryEngine(
          episodes: episodes,
          summaries: summaries,
          conversations: conversations,
          snippets: snippetRepository,
          activities: activities,
        ),
      );
      final now = DateTime.utc(2026, 8, 25, 12);
      await episodes.create(
        NewMemoryEpisode(
          sourceKey: 'agent-test',
          startedAt: now.subtract(const Duration(hours: 2)),
          endedAt: now.subtract(const Duration(hours: 1)),
          title: 'Kango retrieval architecture',
          summary: 'Implemented deterministic Kango retrieval with evidence.',
          applications: const ['Code'],
          urls: const ['https://github.com/acme/kango'],
          topics: const ['retrieval', 'evidence'],
          entities: const ['project:acme/kango'],
          sourceActivityIds: const [1],
        ),
      );
      await snippets.create(
        NewSnippet(
          title: 'Kango retrieval command',
          content: 'Run the retrieval verification command.',
          createdAt: now,
          updatedAt: now,
        ),
      );
      await memory.remember(
        'Kango retrieval passed the evidence review.',
        at: now,
      );
      await memory.remember(
        'Kango retrieval daily summary.',
        at: now,
        kind: SummaryKind.daily,
      );
      final conversationId = await conversations.create();
      await conversations.appendMessage(
        conversationId,
        LlmRole.user,
        'How does Kango retrieval work?',
      );
      final agent = MemoryAgent(memory: memory);

      final investigation = await agent.investigate('Kango retrieval');
      final report = await agent.deepStudy('Kango retrieval');

      expect(
        investigation.evidence.map((item) => item.kind).toSet(),
        containsAll(MemoryEvidenceKind.values),
      );
      expect(investigation.reflection.sufficient, isTrue);
      expect(
        investigation.steps.map((step) => step.tool),
        contains('search_memory_hybrid'),
      );
      expect(report.markdown, contains('# DeepStudy: Kango retrieval'));
      expect(report.markdown, contains('episode:'));
      expect(report.markdown, contains('Confidence:'));
    },
  );

  test(
    'episode builder identifies GitHub projects without a graph database',
    () {
      final episode =
          const EpisodeBuilder().build([
            Observation(
              id: 1,
              timestamp: DateTime.utc(2026, 8, 25),
              appName: 'Browser',
              windowTitle: 'KangoOS',
              browserUrl: 'https://github.com/OpenKango/KangoOS/issues/42',
              visibleText: 'reviewing issue 42',
            ),
          ]).single;

      expect(episode.entities, contains('project:openkango/kangoos'));
    },
  );
}
