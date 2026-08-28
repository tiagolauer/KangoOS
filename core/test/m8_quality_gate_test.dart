import 'dart:convert';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:test/test.dart';

import '../benchmark/m8_corpus.dart';

void main() {
  test('M8 canonical questions retrieve the correct sources', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final episodes = SqliteEpisodeRepository(database);
    final ids = await seedM8Corpus(episodes);
    final memory = MemoryService(
      database: database,
      activities: SqliteActivityRepository(database),
      summaries: SqliteSummaryRepository(database),
      episodes: episodes,
      queryEngine: MemoryQueryEngine(episodes: episodes),
    );
    final agent = MemoryAgent(memory: memory, referenceTime: m8ReferenceTime);

    for (final canonical in m8CanonicalQuestions) {
      final result = await agent.investigate(
        canonical.question,
        depth: MemoryInvestigationDepth.deep,
      );
      final evidenceIds = result.evidence.map((item) => item.id).toSet();
      final expectedIds =
          canonical.expectedSourceKeys
              .map((key) => 'episode:${ids[key]}')
              .toSet();
      expect(evidenceIds, containsAll(expectedIds), reason: canonical.question);
    }
  });

  test('M8 corpus exposes the database architecture contradiction', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final episodes = SqliteEpisodeRepository(database);
    await seedM8Corpus(episodes);
    final memory = MemoryService(
      database: database,
      activities: SqliteActivityRepository(database),
      summaries: SqliteSummaryRepository(database),
      episodes: episodes,
      queryEngine: MemoryQueryEngine(episodes: episodes),
    );

    final investigation = await MemoryAgent(
      memory: memory,
      referenceTime: m8ReferenceTime,
    ).investigate('banco local LTM', depth: MemoryInvestigationDepth.deep);

    expect(
      investigation.reflection.contradictions,
      isNotEmpty,
      reason: investigation.evidence.map((item) => item.id).join(', '),
    );
    expect(
      investigation.reflection.contradictions.first.evidenceIds,
      containsAll(['episode:1', 'episode:2']),
    );
  });

  test('Desktop and MCP return equivalent grounded agent results', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final episodes = SqliteEpisodeRepository(database);
    await seedM8Corpus(episodes);
    final snippetRepository = SqliteSnippetRepository(database);
    final memory = MemoryService(
      database: database,
      activities: SqliteActivityRepository(database),
      summaries: SqliteSummaryRepository(database),
      episodes: episodes,
      queryEngine: MemoryQueryEngine(episodes: episodes),
    );
    final agent = MemoryAgent(memory: memory, referenceTime: m8ReferenceTime);
    MemoryInvestigation? desktopInvestigation;
    final desktopAnswer =
        await RagChat(
              snippets: SnippetService(repository: snippetRepository),
              memory: memory,
              agent: agent,
              onInvestigation: (value) => desktopInvestigation = value,
            )
            .reply(
              provider: _equivalenceProvider(),
              history: const [],
              userMessage: 'Qual decisão tomamos sobre o banco local?',
            )
            .join();
    final mcpResponse = await KangoMcpServer(
      snippets: SnippetService(repository: snippetRepository),
      memory: memory,
      agent: agent,
      llmProvider: _equivalenceProvider(),
    ).callTool('ask_kango_ltm', {
      'query': 'Qual decisão tomamos sobre o banco local?',
    });
    final mcpResult =
        jsonDecode(
              ((mcpResponse['content'] as List).single as Map)['text']
                  as String,
            )
            as Map<String, Object?>;
    final mcpInvestigation =
        mcpResult['investigation']! as Map<String, Object?>;
    final mcpEvidenceIds =
        (mcpInvestigation['evidence']! as List)
            .cast<Map>()
            .map((item) => item['id'] as String)
            .toSet();

    expect(desktopAnswer, mcpResult['answer']);
    expect(
      desktopInvestigation!.evidence.map((item) => item.id).toSet(),
      mcpEvidenceIds,
    );
    expect(desktopAnswer, contains('[episode:2]'));
  });

  test('agent recovers once from a narrow empty tool choice', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final episodes = SqliteEpisodeRepository(database);
    await seedM8Corpus(episodes);
    final summaries = SqliteSummaryRepository(database);
    await seedM8Corroboration(summaries);
    final memory = MemoryService(
      database: database,
      activities: SqliteActivityRepository(database),
      summaries: summaries,
      episodes: episodes,
      queryEngine: MemoryQueryEngine(episodes: episodes, summaries: summaries),
    );
    final provider = _ScriptedLlmProvider([
      const LlmResponse(
        content: '',
        toolCalls: [
          LlmToolCall(
            id: 'narrow',
            name: 'search_conversations',
            arguments: {'query': 'sync KangoOS'},
          ),
        ],
        stopReason: LlmStopReason.toolCalls,
      ),
      const LlmResponse(content: 'Não encontrei.'),
      const LlmResponse(content: 'Encontrei a fonte correta.'),
      const LlmResponse(
        content: 'A última alteração foi registrada [episode:6].',
      ),
    ]);

    final run = await MemoryAgent(
      memory: memory,
      referenceTime: m8ReferenceTime,
    ).run(
      provider: provider,
      query: 'Quando mexi pela última vez no sync do KangoOS?',
    );

    expect(run.stopReason, MemoryAgentStopReason.completed);
    expect(
      run.investigation.evidence.map((item) => item.id),
      contains('episode:6'),
    );
    expect(
      run.investigation.steps.map((item) => item.tool),
      containsAll(['search_conversations', 'search_memory', 'reflect_memory']),
    );
  });
}

_ScriptedLlmProvider _equivalenceProvider() => _ScriptedLlmProvider([
  const LlmResponse(
    content: '',
    toolCalls: [
      LlmToolCall(
        id: 'search',
        name: 'search_memory',
        arguments: {'query': 'banco local LTM', 'limit': 10},
      ),
    ],
    stopReason: LlmStopReason.toolCalls,
  ),
  const LlmResponse(
    content: '',
    toolCalls: [
      LlmToolCall(
        id: 'reflect',
        name: 'reflect_memory',
        arguments: {
          'relevantEvidenceIds': ['episode:1', 'episode:2'],
          'contradictions': [
            {
              'description': 'O plano inicial foi substituído.',
              'evidenceIds': ['episode:1', 'episode:2'],
            },
          ],
          'gaps': [],
          'sufficient': true,
        },
      ),
    ],
    stopReason: LlmStopReason.toolCalls,
  ),
  const LlmResponse(
    content:
        'Decidimos usar SQLite local criptografado com SQLCipher [episode:2].',
  ),
]);

class _ScriptedLlmProvider extends LlmProvider {
  _ScriptedLlmProvider(this.responses);

  final List<LlmResponse> responses;

  @override
  String get id => 'm8-scripted';

  @override
  bool get supportsToolCalls => true;

  @override
  Stream<String> chat(List<LlmMessage> messages) => const Stream.empty();

  @override
  Future<LlmResponse> complete(
    List<LlmMessage> messages, {
    List<LlmToolDefinition> tools = const [],
  }) async => responses.removeAt(0);
}
