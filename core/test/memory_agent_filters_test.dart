import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:test/test.dart';

class _FilterProvider extends LlmProvider {
  var _step = 0;

  @override
  String get id => 'filter-provider';

  @override
  Stream<String> chat(List<LlmMessage> messages) => const Stream.empty();

  @override
  Future<LlmResponse> complete(
    List<LlmMessage> messages, {
    List<LlmToolDefinition> tools = const [],
  }) async {
    _step++;
    if (_step == 1) {
      return const LlmResponse(
        content: '',
        toolCalls: [
          LlmToolCall(
            id: 'search-1',
            name: 'search_memory',
            arguments: {'query': 'release', 'limit': 10},
          ),
        ],
        stopReason: LlmStopReason.toolCalls,
      );
    }
    if (_step == 2) {
      return const LlmResponse(content: 'A entrega foi concluída.');
    }
    return const LlmResponse(content: 'Confirmado [episode:1].');
  }
}

void main() {
  test('agent uses the same application filters selected by the UI', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final episodes = SqliteEpisodeRepository(database);
    final activities = SqliteActivityRepository(database);
    final summaries = SqliteSummaryRepository(database);
    final conversations = SqliteConversationRepository(database);
    final snippets = SqliteSnippetRepository(database);
    final memory = MemoryService(
      database: database,
      activities: activities,
      summaries: summaries,
      episodes: episodes,
      queryEngine: MemoryQueryEngine(
        episodes: episodes,
        activities: activities,
        summaries: summaries,
        conversations: conversations,
        snippets: snippets,
      ),
    );
    final now = DateTime.utc(2026, 8, 26, 12);
    await episodes.create(
      NewMemoryEpisode(
        sourceKey: 'code-release',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 30)),
        title: 'Release do código',
        summary: 'release concluída',
        applications: const ['Code'],
        urls: const [],
        topics: const ['release'],
        entities: const [],
        sourceActivityIds: const [],
      ),
    );
    await episodes.create(
      NewMemoryEpisode(
        sourceKey: 'mail-release',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 30)),
        title: 'Release por e-mail',
        summary: 'release adiada',
        applications: const ['Mail'],
        urls: const [],
        topics: const ['release'],
        entities: const [],
        sourceActivityIds: const [],
      ),
    );

    final run = await MemoryAgent(memory: memory).run(
      provider: _FilterProvider(),
      query: 'Como ficou a release?',
      filters: const MemorySearchFilters(applications: {'Code'}),
    );

    expect(run.investigation.evidence.map((item) => item.id), ['episode:1']);
  });
}
