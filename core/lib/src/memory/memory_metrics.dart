import 'package:drift/drift.dart';

import '../database/database.dart';

const maxMemoryMetricSamples = 256;

class MemoryRuntimeMetricsSnapshot {
  const MemoryRuntimeMetricsSnapshot({
    required this.searchCount,
    required this.searchFailures,
    required this.searchP95,
    required this.agentRuns,
    required this.agentAverageSteps,
    required this.agentMaxSteps,
    required this.agentStopReasons,
  });

  final int searchCount;
  final int searchFailures;
  final Duration searchP95;
  final int agentRuns;
  final double agentAverageSteps;
  final int agentMaxSteps;
  final Map<String, int> agentStopReasons;

  Map<String, Object?> toJson() => {
    'searchCount': searchCount,
    'searchFailures': searchFailures,
    'searchP95Ms': searchP95.inMicroseconds / 1000,
    'agentRuns': agentRuns,
    'agentAverageSteps': agentAverageSteps,
    'agentMaxSteps': agentMaxSteps,
    'agentStopReasons': agentStopReasons,
  };
}

class LocalMemoryMetrics {
  final _searchDurations = <Duration>[];
  final _agentStopReasons = <String, int>{};
  var _searchCount = 0;
  var _searchFailures = 0;
  var _agentRuns = 0;
  var _agentSteps = 0;
  var _agentMaxSteps = 0;

  void recordSearch(Duration duration, {required bool failed}) {
    _searchCount++;
    if (failed) _searchFailures++;
    _searchDurations.add(duration);
    if (_searchDurations.length > maxMemoryMetricSamples) {
      _searchDurations.removeAt(0);
    }
  }

  void recordAgent({required int steps, required String stopReason}) {
    _agentRuns++;
    _agentSteps += steps;
    if (steps > _agentMaxSteps) _agentMaxSteps = steps;
    _agentStopReasons[stopReason] = (_agentStopReasons[stopReason] ?? 0) + 1;
  }

  MemoryRuntimeMetricsSnapshot snapshot() {
    final sorted = [..._searchDurations]..sort();
    final p95Index =
        sorted.isEmpty
            ? 0
            : ((sorted.length * 0.95).ceil() - 1).clamp(0, sorted.length - 1);
    return MemoryRuntimeMetricsSnapshot(
      searchCount: _searchCount,
      searchFailures: _searchFailures,
      searchP95: sorted.isEmpty ? Duration.zero : sorted[p95Index],
      agentRuns: _agentRuns,
      agentAverageSteps: _agentRuns == 0 ? 0 : _agentSteps / _agentRuns,
      agentMaxSteps: _agentMaxSteps,
      agentStopReasons: Map.unmodifiable(_agentStopReasons),
    );
  }
}

class MemoryDiagnosticsSnapshot {
  const MemoryDiagnosticsSnapshot({
    required this.pendingFormation,
    required this.formationFailures,
    required this.staleEmbeddings,
    required this.runtime,
  });

  final int pendingFormation;
  final int formationFailures;
  final int staleEmbeddings;
  final MemoryRuntimeMetricsSnapshot runtime;

  Map<String, Object?> toJson() => {
    'pendingFormation': pendingFormation,
    'formationFailures': formationFailures,
    'staleEmbeddings': staleEmbeddings,
    'runtime': runtime.toJson(),
  };
}

class MemoryDiagnosticsService {
  const MemoryDiagnosticsService({required this.database, this.metrics});

  final KangoosDatabase database;
  final LocalMemoryMetrics? metrics;

  Future<MemoryDiagnosticsSnapshot> snapshot({String? providerId}) async {
    final providerCondition =
        providerId == null
            ? '(embedding IS NULL OR embedding_provider_id IS NULL)'
            : '(embedding IS NULL OR embedding_provider_id IS NULL OR '
                'embedding_provider_id <> ?)';
    final variables =
        providerId == null
            ? const <Variable>[]
            : List<Variable>.generate(
              4,
              (_) => Variable.withString(providerId),
            );
    final row =
        await database
            .customSelect(
              '''
SELECT
  (SELECT COUNT(*) FROM memory_episodes
    WHERE formation_status = 'pending') AS pending_formation,
  (SELECT COUNT(*) FROM memory_episodes
    WHERE formation_status = 'failed') AS formation_failures,
  (SELECT COUNT(*) FROM memory_episodes WHERE $providerCondition) +
  (SELECT COUNT(*) FROM activity_summaries WHERE $providerCondition) +
  (SELECT COUNT(*) FROM conversation_messages WHERE $providerCondition) +
  (SELECT COUNT(*) FROM snippets WHERE $providerCondition)
    AS stale_embeddings;
''',
              variables: variables,
              readsFrom: {
                database.memoryEpisodes,
                database.activitySummaries,
                database.conversationMessages,
                database.snippets,
              },
            )
            .getSingle();
    return MemoryDiagnosticsSnapshot(
      pendingFormation: row.read<int>('pending_formation'),
      formationFailures: row.read<int>('formation_failures'),
      staleEmbeddings: row.read<int>('stale_embeddings'),
      runtime: metrics?.snapshot() ?? LocalMemoryMetrics().snapshot(),
    );
  }
}
