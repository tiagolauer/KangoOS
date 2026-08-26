import 'dart:convert';
import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';

import 'm8_corpus.dart';

const m8DefaultSoakSeconds = 24 * 60 * 60;
const m8SoakRssGrowthLimitBytes = 256 * 1024 * 1024;

Future<void> main() async {
  final seconds =
      int.tryParse(Platform.environment['KANGOOS_M8_SOAK_SECONDS'] ?? '') ??
      m8DefaultSoakSeconds;
  if (seconds < 1) throw ArgumentError.value(seconds, 'seconds');
  final database = KangoosDatabase.memory();
  try {
    final episodes = SqliteEpisodeRepository(database);
    final ids = await seedM8Corpus(episodes);
    final metrics = LocalMemoryMetrics();
    final agent = MemoryAgent(
      memory: MemoryService(
        database: database,
        activities: SqliteActivityRepository(database),
        summaries: SqliteSummaryRepository(database),
        episodes: episodes,
        queryEngine: MemoryQueryEngine(episodes: episodes, metrics: metrics),
        metrics: metrics,
      ),
      referenceTime: m8ReferenceTime,
    );
    final initialRss = ProcessInfo.currentRss;
    var maxRss = initialRss;
    var cycles = 0;
    var failures = 0;
    final deadline = DateTime.now().add(Duration(seconds: seconds));
    while (DateTime.now().isBefore(deadline)) {
      for (final canonical in m8CanonicalQuestions) {
        final result = await agent.investigate(canonical.question);
        final evidenceIds = result.evidence.map((item) => item.id).toSet();
        final expectedIds = canonical.expectedSourceKeys.map(
          (key) => 'episode:${ids[key]}',
        );
        if (!evidenceIds.containsAll(expectedIds)) failures++;
      }
      cycles++;
      maxRss =
          maxRss < ProcessInfo.currentRss ? ProcessInfo.currentRss : maxRss;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    final finalRss = ProcessInfo.currentRss;
    final rssGrowth = maxRss - initialRss;
    stdout.writeln(
      jsonEncode({
        'durationSeconds': seconds,
        'cycles': cycles,
        'queries': cycles * m8CanonicalQuestions.length,
        'failures': failures,
        'initialRssBytes': initialRss,
        'maxRssBytes': maxRss,
        'finalRssBytes': finalRss,
        'rssGrowthBytes': rssGrowth,
        'rssGrowthGateBytes': m8SoakRssGrowthLimitBytes,
        'metrics': metrics.snapshot().toJson(),
      }),
    );
    if (cycles == 0 || failures != 0) {
      throw StateError('Soak correctness gate failed.');
    }
    if (rssGrowth > m8SoakRssGrowthLimitBytes) {
      throw StateError('Soak RSS growth gate failed: $rssGrowth bytes.');
    }
  } finally {
    await database.close();
  }
}
