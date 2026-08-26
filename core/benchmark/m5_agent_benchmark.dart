import 'dart:convert';
import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';

const defaultM5BenchmarkBaseUrl = 'http://127.0.0.1:1234/v1';
const defaultM5BenchmarkModel = 'qwen/qwen3-8b';

Future<void> main() async {
  final environment = Platform.environment;
  final provider = OpenAiProvider(
    apiKey: '',
    baseUrl:
        environment['KANGOOS_BENCHMARK_LLM_BASE_URL'] ??
        defaultM5BenchmarkBaseUrl,
    model:
        environment['KANGOOS_BENCHMARK_LLM_MODEL'] ?? defaultM5BenchmarkModel,
  );
  final database = KangoosDatabase.memory();
  try {
    final episodes = SqliteEpisodeRepository(database);
    final summaries = SqliteSummaryRepository(database);
    final conversations = SqliteConversationRepository(database);
    final snippets = SqliteSnippetRepository(database);
    final activities = SqliteActivityRepository(database);
    final memory = MemoryService(
      database: database,
      activities: activities,
      summaries: summaries,
      episodes: episodes,
      queryEngine: MemoryQueryEngine(
        episodes: episodes,
        summaries: summaries,
        conversations: conversations,
        snippets: snippets,
        activities: activities,
      ),
    );
    await episodes.create(
      NewMemoryEpisode(
        sourceKey: 'm5-live-benchmark',
        startedAt: DateTime.utc(2026, 8, 26, 14),
        endedAt: DateTime.utc(2026, 8, 26, 15),
        title: 'Decisão do agente M5',
        summary:
            'Na reunião do KangoOS decidimos limitar o agente a oito passos.',
        applications: const ['KangoOS'],
        urls: const [],
        topics: const ['M5', 'agente'],
        entities: const ['project:KangoOS'],
        decisions: const ['Limitar o agente a oito passos.'],
        sourceActivityIds: const [],
      ),
    );
    await memory.remember(
      'O Chat e o MCP usam exatamente o mesmo MemoryAgent no M5.',
      at: DateTime.utc(2026, 8, 26, 15),
    );
    await snippets.create(
      NewSnippet(
        title: 'Contrato do agente M5',
        content: 'Chat e MCP compartilham o mesmo agente de memória.',
        tags: const ['M5', 'agente'],
        createdAt: DateTime.utc(2026, 8, 26, 15),
        updatedAt: DateTime.utc(2026, 8, 26, 15),
      ),
    );
    final preflight = await memory.searchMemory(
      'agente',
      mode: MemorySearchMode.lexical,
    );

    final stopwatch = Stopwatch()..start();
    final run = await MemoryAgent(memory: memory).run(
      provider: provider,
      query:
          'Qual foi a decisão sobre o limite do agente M5 e quais interfaces usam o mesmo agente?',
      depth: MemoryInvestigationDepth.deep,
    );
    stopwatch.stop();

    stdout.writeln(
      jsonEncode({
        'provider': provider.id,
        'model':
            environment['KANGOOS_BENCHMARK_LLM_MODEL'] ??
            defaultM5BenchmarkModel,
        'durationMs': stopwatch.elapsedMilliseconds,
        'stepCount': run.stepCount,
        'stopReason': run.stopReason.name,
        'tools':
            run.investigation.steps
                .map(
                  (step) => {
                    'name': step.tool,
                    'query': step.query,
                    'resultCount': step.resultCount,
                    'error': step.error,
                  },
                )
                .toList(),
        'evidence': run.investigation.evidence.map((item) => item.id).toList(),
        'preflightEvidence': preflight.evidence.map((item) => item.id).toList(),
        'answer': run.answer,
      }),
    );
    if (run.stopReason != MemoryAgentStopReason.completed) {
      throw StateError('Agent stopped with ${run.stopReason.name}.');
    }
    if (run.investigation.evidence.length < 2) {
      throw StateError('Agent did not collect enough evidence.');
    }
    if (!RegExp(r'\[(episode|summary):\d+\]').hasMatch(run.answer)) {
      throw StateError('Agent answer did not cite memory evidence.');
    }
    if (!run.investigation.steps.any((step) => step.tool == 'reflect_memory')) {
      throw StateError('Agent did not reflect before answering.');
    }
  } finally {
    await database.close();
  }
}
