import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:test/test.dart';

class _MetricsEmbeddingProvider implements EmbeddingProvider {
  @override
  String get id => 'm8-metrics';

  @override
  Future<List<double>> embed(String text) async => const [1, 0];
}

class _MetricsLlmProvider extends LlmProvider {
  @override
  String get id => 'm8-metrics-llm';

  @override
  Stream<String> chat(List<LlmMessage> messages) => const Stream.empty();

  @override
  Future<LlmResponse> complete(
    List<LlmMessage> messages, {
    List<LlmToolDefinition> tools = const [],
  }) async => const LlmResponse(content: 'Sem evidência suficiente.');
}

void main() {
  test('diagnostics contain aggregate health only', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final episodes = SqliteEpisodeRepository(database);
    final snippets = SqliteSnippetRepository(database);
    final metrics = LocalMemoryMetrics();
    final provider = _MetricsEmbeddingProvider();
    final queryEngine = MemoryQueryEngine(
      episodes: episodes,
      snippets: snippets,
      embeddingProvider: provider,
      metrics: metrics,
    );
    final memory = MemoryService(
      database: database,
      activities: SqliteActivityRepository(database),
      summaries: SqliteSummaryRepository(database),
      episodes: episodes,
      queryEngine: queryEngine,
      metrics: metrics,
    );
    final at = DateTime.utc(2026, 8, 26, 10);
    for (final status in const [
      MemoryFormationStatus.pending,
      MemoryFormationStatus.failed,
    ]) {
      await episodes.create(
        NewMemoryEpisode(
          sourceKey: 'metrics-${status.name}',
          startedAt: at,
          endedAt: at.add(const Duration(minutes: 1)),
          title: 'M8 ${status.name}',
          summary: 'Aggregate diagnostics marker',
          applications: const ['KangoOS'],
          urls: const [],
          topics: const ['M8'],
          entities: const [],
          sourceActivityIds: const [],
          formationStatus: status,
        ),
      );
    }
    await snippets.create(
      NewSnippet(
        title: 'M8 metrics',
        content: 'No personal content in diagnostics',
        createdAt: at,
        updatedAt: at,
      ),
    );

    await memory.searchMemory('diagnostics', mode: MemorySearchMode.lexical);
    await expectLater(
      memory.searchMemory(
        'invalid',
        filters: MemorySearchFilters(start: at, end: at),
      ),
      throwsArgumentError,
    );
    await MemoryAgent(
      memory: memory,
    ).run(provider: _MetricsLlmProvider(), query: 'Existe evidência?');

    final snapshot = await memory.diagnostics();
    expect(snapshot.pendingFormation, 1);
    expect(snapshot.formationFailures, 1);
    expect(snapshot.staleEmbeddings, 3);
    expect(snapshot.runtime.searchCount, 2);
    expect(snapshot.runtime.searchFailures, 1);
    expect(snapshot.runtime.agentRuns, 1);
    expect(snapshot.runtime.agentMaxSteps, 1);
    expect(snapshot.toJson().toString(), isNot(contains('marker')));
    expect(snapshot.toJson().toString(), isNot(contains('personal')));
  });
}
