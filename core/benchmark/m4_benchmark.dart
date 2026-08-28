import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';

const m4BenchmarkEpisodeCount = 50000;
const m4BenchmarkRuns = 20;
const m4PreindexedP95Limit = Duration(milliseconds: 300);
const m4CompleteQueryP95Limit = Duration(seconds: 2);
const m4AllowedRegression = 0.2;
const m4RegressionNoiseAllowanceMs = 2.0;

double m4RegressionLimitMs(double baselineMs) =>
    baselineMs +
    baselineMs * m4AllowedRegression +
    m4RegressionNoiseAllowanceMs;

class _LocalBenchmarkEmbeddingProvider implements EmbeddingProvider {
  @override
  String get id => 'm4-local-benchmark-v1';

  @override
  Future<List<double>> embed(String text) async {
    final vector = List<double>.filled(32, 0);
    for (final rune in text.toLowerCase().runes) {
      vector[rune % vector.length]++;
    }
    return vector;
  }
}

Future<void> main() async {
  final environment = Platform.environment;
  final baseUrl = environment['KANGOOS_BENCHMARK_EMBEDDING_BASE_URL'];
  final model = environment['KANGOOS_BENCHMARK_EMBEDDING_MODEL'];
  if ((baseUrl == null) != (model == null)) {
    throw StateError(
      'Configure KANGOOS_BENCHMARK_EMBEDDING_BASE_URL and '
      'KANGOOS_BENCHMARK_EMBEDDING_MODEL together.',
    );
  }
  final EmbeddingProvider provider =
      baseUrl == null
          ? _LocalBenchmarkEmbeddingProvider()
          : OpenAiEmbeddingProvider(baseUrl: baseUrl, model: model!);
  final seedVector = await provider.embed('KangoOS M4 benchmark seed');
  final database = KangoosDatabase.memory();
  try {
    await database.allSnippets();
    final startedAt = DateTime.utc(2026, 1, 1);
    await database.batch((batch) {
      for (var index = 0; index < m4BenchmarkEpisodeCount; index++) {
        batch.insert(
          database.memoryEpisodes,
          MemoryEpisodesCompanion.insert(
            sourceKey: 'm4-benchmark-$index',
            startedAt: startedAt.add(Duration(seconds: index)),
            endedAt: startedAt.add(Duration(seconds: index + 1)),
            title: 'Benchmark episode $index needle$index',
            summary: 'Preindexed KangoOS memory benchmark item $index',
            applications: const Value(['Benchmark']),
            topics: Value(['needle$index']),
            embedding: Value(seedVector),
            embeddingProviderId: Value(provider.id),
          ),
        );
      }
    });
    final engine = MemoryQueryEngine(
      episodes: SqliteEpisodeRepository(database),
      embeddingProvider: provider,
    );
    final target = 'needle${m4BenchmarkEpisodeCount - 1}';
    await engine.search(target, mode: MemorySearchMode.lexical);
    final lexicalDurations = await _measure(
      () => engine.search(target, mode: MemorySearchMode.lexical),
    );
    await engine.search(target);
    final completeDurations = await _measure(() => engine.search(target));
    final lexicalP95 = _percentile95(lexicalDurations);
    final completeP95 = _percentile95(completeDurations);
    final baseline = await _baseline(provider.id);
    final lexicalRegressionLimit =
        baseline == null
            ? null
            : m4RegressionLimitMs(baseline.preindexedP95Ms);
    final completeRegressionLimit =
        baseline == null
            ? null
            : m4RegressionLimitMs(baseline.completeP95Ms);
    final lexicalP95Ms = lexicalP95.inMicroseconds / 1000;
    final completeP95Ms = completeP95.inMicroseconds / 1000;
    final report = {
      'corpusVersion': 1,
      'episodes': m4BenchmarkEpisodeCount,
      'runs': m4BenchmarkRuns,
      'provider': provider.id,
      'embeddingDimensions': seedVector.length,
      'preindexedSearchP95Ms': lexicalP95Ms,
      'completeQueryP95Ms': completeP95Ms,
      'preindexedGateMs': m4PreindexedP95Limit.inMilliseconds,
      'completeQueryGateMs': m4CompleteQueryP95Limit.inMilliseconds,
      'baseline': baseline?.toJson(),
      'allowedRegression': m4AllowedRegression,
      'regressionNoiseAllowanceMs': m4RegressionNoiseAllowanceMs,
    };
    stdout.writeln(jsonEncode(report));
    if (lexicalP95 > m4PreindexedP95Limit) {
      throw StateError('Preindexed search p95 gate failed: $lexicalP95');
    }
    if (completeP95 > m4CompleteQueryP95Limit) {
      throw StateError('Complete query p95 gate failed: $completeP95');
    }
    if (lexicalRegressionLimit != null &&
        lexicalP95Ms > lexicalRegressionLimit) {
      throw StateError(
        'Preindexed search regression gate failed: '
        '$lexicalP95Ms ms > $lexicalRegressionLimit ms',
      );
    }
    if (completeRegressionLimit != null &&
        completeP95Ms > completeRegressionLimit) {
      throw StateError(
        'Complete query regression gate failed: '
        '$completeP95Ms ms > $completeRegressionLimit ms',
      );
    }
  } finally {
    await database.close();
  }
}

Future<_BenchmarkBaseline?> _baseline(String providerId) async {
  final file = File.fromUri(Platform.script.resolve('m4_baseline.json'));
  if (!await file.exists()) return null;
  final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final providers = json['providers'] as Map<String, dynamic>?;
  final values = providers?[providerId] as Map<String, dynamic>?;
  if (values == null) return null;
  return _BenchmarkBaseline(
    preindexedP95Ms: (values['preindexedSearchP95Ms'] as num).toDouble(),
    completeP95Ms: (values['completeQueryP95Ms'] as num).toDouble(),
  );
}

Future<List<Duration>> _measure(Future<Object?> Function() action) async {
  final durations = <Duration>[];
  for (var run = 0; run < m4BenchmarkRuns; run++) {
    final stopwatch = Stopwatch()..start();
    await action();
    stopwatch.stop();
    durations.add(stopwatch.elapsed);
  }
  return durations;
}

Duration _percentile95(List<Duration> values) {
  final sorted = [...values]..sort();
  final index = ((sorted.length * 0.95).ceil() - 1).clamp(0, sorted.length - 1);
  return sorted[index];
}

class _BenchmarkBaseline {
  const _BenchmarkBaseline({
    required this.preindexedP95Ms,
    required this.completeP95Ms,
  });

  final double preindexedP95Ms;
  final double completeP95Ms;

  Map<String, double> toJson() => {
    'preindexedSearchP95Ms': preindexedP95Ms,
    'completeQueryP95Ms': completeP95Ms,
  };
}
