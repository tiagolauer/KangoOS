import '../database/database.dart';
import '../database/tables/memory_episodes_table.dart';
import '../embedding/embedding_provider.dart';
import 'activity_repository.dart';
import 'episode_builder.dart';
import 'episode_repository.dart';
import 'memory_enricher.dart';
import 'observation.dart';

class MemoryFormationReport {
  const MemoryFormationReport({
    required this.created,
    required this.indexed,
    required this.indexingFailures,
    this.updated = 0,
    this.enriched = 0,
    this.enrichmentFailures = const {},
  });

  final int created;
  final int updated;
  final int enriched;
  final int indexed;
  final Map<int, Object> enrichmentFailures;
  final Map<int, Object> indexingFailures;
}

class MemoryBackfillBatch {
  const MemoryBackfillBatch({
    required this.report,
    required this.cursor,
    required this.completed,
  });

  final MemoryFormationReport report;
  final DateTime cursor;
  final bool completed;
}

class MemoryFormationService {
  const MemoryFormationService({
    required this.activities,
    required this.episodes,
    this.embeddingProvider,
    this.builder = const EpisodeBuilder(),
  });

  final ActivityRepository activities;
  final EpisodeRepository episodes;
  final EmbeddingProvider? embeddingProvider;
  final EpisodeBuilder builder;

  Future<MemoryFormationReport> formBetween(
    DateTime start,
    DateTime end, {
    bool indexEmbeddings = true,
    MemoryEpisodeEnricher? enricher,
  }) async {
    final observations =
        (await activities.between(
          start,
          end,
        )).map(Observation.fromActivity).toList();
    var created = 0;
    var updated = 0;
    var enriched = 0;
    var indexed = 0;
    final enrichmentFailures = <int, Object>{};
    final indexingFailures = <int, Object>{};
    for (final draft in builder.build(observations)) {
      final existing = await episodes.bySourceKey(draft.sourceKey);
      final baseChanged =
          existing == null ||
          existing.contentHash != draft.contentHash ||
          existing.formationVersion != draft.formationVersion;
      final modelChanged =
          enricher != null && existing?.formationModelId != enricher.modelId;
      final retryEnrichment =
          enricher != null &&
          existing?.formationStatus != MemoryFormationStatus.enriched;
      final needsEnrichment =
          enricher != null && (baseChanged || modelChanged || retryEnrichment);
      final needsReplacement =
          existing != null && (baseChanged || modelChanged || retryEnrichment);

      final int id;
      if (existing == null) {
        id = await episodes.create(draft);
        created++;
      } else {
        id = existing.id;
        if (needsReplacement) {
          await episodes.replace(id, draft);
          updated++;
        }
      }

      if (needsEnrichment) {
        await episodes.replace(
          id,
          draft.copyWith(
            formationStatus: MemoryFormationStatus.pending,
            formationModelId: enricher.modelId,
          ),
        );
        try {
          await episodes.replace(id, await enricher.enrich(draft));
          enriched++;
        } catch (error) {
          enrichmentFailures[id] = error;
          await episodes.replace(
            id,
            draft.copyWith(
              formationStatus: MemoryFormationStatus.failed,
              formationModelId: enricher.modelId,
            ),
          );
        }
      }

      if (existing != null && !needsReplacement && !needsEnrichment) continue;
      final episode = await episodes.get(id);
      if (episode == null) {
        throw StateError('Memory episode #$id could not be loaded.');
      }
      try {
        if (indexEmbeddings && await _index(episode)) indexed++;
      } catch (error) {
        indexingFailures[id] = error;
      }
    }
    return MemoryFormationReport(
      created: created,
      updated: updated,
      enriched: enriched,
      indexed: indexed,
      enrichmentFailures: enrichmentFailures,
      indexingFailures: indexingFailures,
    );
  }

  Future<MemoryBackfillBatch> backfillBatch({
    required DateTime start,
    required DateTime end,
    DateTime? cursor,
    Duration batchSpan = const Duration(days: 1),
    bool indexEmbeddings = true,
    MemoryEpisodeEnricher? enricher,
  }) async {
    if (batchSpan <= Duration.zero) {
      throw ArgumentError.value(batchSpan, 'batchSpan', 'must be positive');
    }
    final batchStart =
        cursor == null || cursor.isBefore(start) ? start : cursor;
    if (!batchStart.isBefore(end)) {
      return MemoryBackfillBatch(
        report: _emptyReport,
        cursor: end,
        completed: true,
      );
    }
    final proposedEnd = batchStart.add(batchSpan);
    final batchEnd = proposedEnd.isBefore(end) ? proposedEnd : end;
    return MemoryBackfillBatch(
      report: await formBetween(
        batchStart,
        batchEnd,
        indexEmbeddings: indexEmbeddings,
        enricher: enricher,
      ),
      cursor: batchEnd,
      completed: !batchEnd.isBefore(end),
    );
  }

  Future<bool> _index(MemoryEpisode episode) async {
    final provider = embeddingProvider;
    if (provider == null) return false;
    final providerId = await embeddingProviderFingerprint(provider);
    final text = [
      episode.title,
      episode.summary,
      episode.topics.join(' '),
      episode.entities.join(' '),
      episode.decisions.join(' '),
      episode.actionItems.join(' '),
      episode.technologies.join(' '),
    ].join('\n');
    await episodes.setEmbedding(
      episode.id,
      await provider.embed(text),
      providerId,
    );
    return true;
  }

  Future<MemoryFormationReport> indexPending() async {
    final provider = embeddingProvider;
    if (provider == null) return _emptyReport;
    final providerId = await embeddingProviderFingerprint(provider);
    var indexed = 0;
    final failures = <int, Object>{};
    for (final episode in await episodes.pendingEmbedding(providerId)) {
      try {
        if (await _index(episode)) indexed++;
      } catch (error) {
        failures[episode.id] = error;
      }
    }
    return MemoryFormationReport(
      created: 0,
      indexed: indexed,
      indexingFailures: failures,
    );
  }
}

const _emptyReport = MemoryFormationReport(
  created: 0,
  indexed: 0,
  indexingFailures: {},
);
