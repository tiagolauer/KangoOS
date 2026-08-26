import '../database/database.dart';
import '../embedding/embedding_provider.dart';
import 'activity_repository.dart';
import 'episode_builder.dart';
import 'episode_repository.dart';
import 'observation.dart';

class MemoryFormationReport {
  const MemoryFormationReport({
    required this.created,
    required this.indexed,
    required this.indexingFailures,
  });

  final int created;
  final int indexed;
  final Map<int, Object> indexingFailures;
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
  }) async {
    final observations = (await activities.between(start, end))
        .map(Observation.fromActivity)
        .toList();
    var created = 0;
    var indexed = 0;
    final failures = <int, Object>{};
    for (final draft in builder.build(observations)) {
      if (await episodes.bySourceKey(draft.sourceKey) != null) continue;
      final id = await episodes.create(draft);
      created++;
      final episode = await episodes.get(id);
      if (episode == null) {
        throw StateError('Created memory episode #$id could not be loaded.');
      }
      try {
        if (indexEmbeddings && await _index(episode)) indexed++;
      } catch (error) {
        failures[id] = error;
      }
    }
    return MemoryFormationReport(
      created: created,
      indexed: indexed,
      indexingFailures: failures,
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
    if (provider == null) {
      return const MemoryFormationReport(
        created: 0,
        indexed: 0,
        indexingFailures: {},
      );
    }
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
