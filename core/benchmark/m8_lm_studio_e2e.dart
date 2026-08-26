import 'dart:convert';
import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';

import 'm8_corpus.dart';

const m8LmStudioBaseUrl = 'http://127.0.0.1:1234/v1';
const m8LmStudioModel = 'qwen/qwen3-8b';

Future<void> main() async {
  final database = KangoosDatabase.memory();
  try {
    final episodes = SqliteEpisodeRepository(database);
    final ids = await seedM8Corpus(episodes);
    final summaries = SqliteSummaryRepository(database);
    await seedM8Corroboration(summaries);
    final metrics = LocalMemoryMetrics();
    final memory = MemoryService(
      database: database,
      activities: SqliteActivityRepository(database),
      summaries: summaries,
      episodes: episodes,
      queryEngine: MemoryQueryEngine(episodes: episodes, metrics: metrics),
      metrics: metrics,
    );
    final provider = OpenAiProvider(
      apiKey: '',
      baseUrl: m8LmStudioBaseUrl,
      model: m8LmStudioModel,
    );
    final agent = MemoryAgent(
      memory: memory,
      metrics: metrics,
      referenceTime: m8ReferenceTime,
    );
    var passed = 0;
    final durations = <int>[];
    final steps = <int>[];
    final cases = <Map<String, Object?>>[];
    for (final canonical in m8CanonicalQuestions) {
      final stopwatch = Stopwatch()..start();
      final run = await agent.run(
        provider: provider,
        query: canonical.question,
      );
      stopwatch.stop();
      durations.add(stopwatch.elapsedMilliseconds);
      steps.add(run.stepCount);
      final evidenceIds =
          run.investigation.evidence.map((item) => item.id).toSet();
      final expectedIds =
          canonical.expectedSourceKeys
              .map((key) => 'episode:${ids[key]}')
              .toSet();
      final cited = expectedIds.any(run.answer.contains);
      final reflected = run.investigation.steps.any(
        (step) => step.tool == 'reflect_memory',
      );
      final casePassed =
          run.stopReason == MemoryAgentStopReason.completed &&
          evidenceIds.containsAll(expectedIds) &&
          cited &&
          reflected;
      if (casePassed) passed++;
      cases.add({
        'passed': casePassed,
        'stopReason': run.stopReason.name,
        'evidenceCount': evidenceIds.length,
        'expectedCount': expectedIds.length,
        'cited': cited,
        'reflected': reflected,
        'reflectionSufficient': run.investigation.reflection.sufficient,
        'toolNames': run.investigation.steps.map((step) => step.tool).toList(),
        'steps': run.stepCount,
        'durationMs': stopwatch.elapsedMilliseconds,
      });
    }
    stdout.writeln(
      jsonEncode({
        'provider': provider.id,
        'model': m8LmStudioModel,
        'questions': m8CanonicalQuestions.length,
        'passed': passed,
        'durationMs': durations.fold<int>(0, (sum, item) => sum + item),
        'maxSteps': steps.fold<int>(
          0,
          (value, item) => value > item ? value : item,
        ),
        'cases': cases,
        'metrics': metrics.snapshot().toJson(),
      }),
    );
    if (passed != m8CanonicalQuestions.length) {
      throw StateError(
        'LM Studio canonical gate failed: $passed/${m8CanonicalQuestions.length}.',
      );
    }
  } finally {
    await database.close();
  }
}
