import '../chat/conversation_repository.dart';
import '../chat/temporal_query.dart';
import '../database/database.dart';
import '../database/tables/activity_summaries_table.dart';
import '../embedding/embedding_provider.dart';
import '../search/vector_index.dart';
import '../snippets/snippet_repository.dart';
import 'activity_repository.dart';
import 'episode_repository.dart';
import 'memory_deletion.dart';
import 'summary_repository.dart';

const reciprocalRankFusionOffset = 60;
const defaultMemorySemanticMinSimilarity = 0.35;
const defaultMemoryVectorCacheTtl = Duration(minutes: 1);
const defaultTemporalAnchorWindow = Duration(hours: 4);
const defaultTemporalPointWindow = Duration(minutes: 30);

enum MemoryEvidenceSource {
  episode,
  summary,
  durableMemory,
  conversation,
  snippet,
}

enum MemorySearchMode { hybrid, lexical, semantic, temporal }

class MemorySearchFilters {
  const MemorySearchFilters({
    this.sources = const {},
    this.applications = const {},
    this.modalities = const {},
    this.projects = const {},
    this.start,
    this.end,
  });

  final Set<MemoryEvidenceSource> sources;
  final Set<String> applications;
  final Set<MemoryModality> modalities;
  final Set<String> projects;
  final DateTime? start;
  final DateTime? end;

  void validate() {
    if (start != null && end != null && !start!.isBefore(end!)) {
      throw ArgumentError.value(end, 'end', 'must be after start');
    }
  }

  MemorySearchFilters withInterval(DateTime? nextStart, DateTime? nextEnd) =>
      MemorySearchFilters(
        sources: sources,
        applications: applications,
        modalities: modalities,
        projects: projects,
        start: nextStart,
        end: nextEnd,
      );

  MemorySearchFilters withoutInterval() => withInterval(null, null);
}

class MemorySearchEvidence {
  const MemorySearchEvidence({
    required this.id,
    required this.source,
    required this.sourceId,
    required this.title,
    required this.content,
    required this.startedAt,
    required this.endedAt,
    required this.score,
    required this.matchReasons,
    this.applications = const [],
    this.modalities = const {},
    this.projects = const [],
    this.semanticSimilarity,
  });

  final String id;
  final MemoryEvidenceSource source;
  final int sourceId;
  final String title;
  final String content;
  final DateTime startedAt;
  final DateTime endedAt;
  final double score;
  final List<String> matchReasons;
  final List<String> applications;
  final Set<MemoryModality> modalities;
  final List<String> projects;
  final double? semanticSimilarity;
}

class MemoryMatch {
  const MemoryMatch({
    required this.episode,
    required this.score,
    required this.lexical,
    required this.semantic,
  });

  final MemoryEpisode episode;
  final double score;
  final bool lexical;
  final bool semantic;
}

class MemorySearchResult {
  const MemorySearchResult({
    this.matches = const [],
    this.evidence = const [],
    this.temporal,
    this.semanticError,
  });

  final List<MemoryMatch> matches;
  final List<MemorySearchEvidence> evidence;
  final TemporalQuery? temporal;
  final Object? semanticError;
}

class MemoryIndexingReport {
  const MemoryIndexingReport({required this.indexed, required this.failures});

  final int indexed;
  final Map<String, Object> failures;
}

class MemoryQueryEngine {
  MemoryQueryEngine({
    required this.episodes,
    this.summaries,
    this.conversations,
    this.snippets,
    this.activities,
    this.embeddingProvider,
    this.temporalParser = const RuleBasedTemporalParser(),
    this.vectorIndex = const BruteForceVectorIndex(),
    this.minSemanticSimilarity = defaultMemorySemanticMinSimilarity,
    this.vectorCacheTtl = defaultMemoryVectorCacheTtl,
  });

  final EpisodeRepository episodes;
  final SummaryRepository? summaries;
  final ConversationRepository? conversations;
  final SnippetRepository? snippets;
  final ActivityRepository? activities;
  final EmbeddingProvider? embeddingProvider;
  final TemporalParser temporalParser;
  final VectorIndex<String> vectorIndex;
  final double minSemanticSimilarity;
  final Duration vectorCacheTtl;

  String? _cachedVectorProviderId;
  DateTime? _vectorsCachedAt;
  List<VectorEntry<String>>? _cachedVectors;

  Future<MemoryIndexingReport> indexPending({int limitPerSource = 100}) async {
    if (limitPerSource < 1) {
      throw ArgumentError.value(limitPerSource, 'limitPerSource');
    }
    final provider = embeddingProvider;
    if (provider == null) {
      return const MemoryIndexingReport(indexed: 0, failures: {});
    }
    final providerId = await embeddingProviderFingerprint(provider);
    final failures = <String, Object>{};
    var indexed = 0;
    indexed += await _indexItems<MemoryEpisode>(
      await episodes.pendingEmbedding(providerId, limit: limitPerSource),
      key: (item) => 'episode:${item.id}',
      content: _episodeContent,
      save:
          (item, vector) => episodes.setEmbedding(item.id, vector, providerId),
      failures: failures,
      provider: provider,
    );
    final summaryRepository = summaries;
    if (summaryRepository != null) {
      indexed += await _indexItems<ActivitySummary>(
        await summaryRepository.pendingEmbedding(
          providerId,
          limit: limitPerSource,
        ),
        key: (item) => 'summary:${item.id}',
        content: (item) => item.content,
        save:
            (item, vector) =>
                summaryRepository.setEmbedding(item.id, vector, providerId),
        failures: failures,
        provider: provider,
      );
    }
    final conversationRepository = conversations;
    if (conversationRepository != null) {
      indexed += await _indexItems<ConversationMessage>(
        await conversationRepository.pendingEmbedding(
          providerId,
          limit: limitPerSource,
        ),
        key: (item) => 'conversation:${item.id}',
        content: (item) => item.content,
        save:
            (item, vector) => conversationRepository.setEmbedding(
              item.id,
              vector,
              providerId,
            ),
        failures: failures,
        provider: provider,
      );
    }
    final snippetRepository = snippets;
    if (snippetRepository != null) {
      indexed += await _indexItems<Snippet>(
        await snippetRepository.pendingEmbedding(
          providerId,
          limit: limitPerSource,
        ),
        key: (item) => 'snippet:${item.id}',
        content:
            (item) => '${item.title}\n${item.content}\n${item.tags.join(' ')}',
        save:
            (item, vector) =>
                snippetRepository.setEmbedding(item.id, vector, providerId),
        failures: failures,
        provider: provider,
      );
    }
    _invalidateVectorCache();
    return MemoryIndexingReport(indexed: indexed, failures: failures);
  }

  Future<MemorySearchResult> search(
    String query, {
    DateTime? reference,
    int limit = 10,
    MemorySearchMode mode = MemorySearchMode.hybrid,
    MemorySearchFilters filters = const MemorySearchFilters(),
  }) async {
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    filters.validate();
    final temporal = await temporalParser.parse(
      query,
      reference ?? DateTime.now(),
    );
    final resolvedTemporal = await _resolveTemporal(temporal, filters);
    final effectiveFilters = _effectiveFilters(filters, resolvedTemporal);
    if (effectiveFilters == null) {
      return MemorySearchResult(temporal: temporal);
    }
    final candidateLimit = limit * 5;
    final ranked = <String, _RankedDocument>{};
    final lexicalText = _lexicalText(query, temporal);

    if ((mode == MemorySearchMode.hybrid || mode == MemorySearchMode.lexical) &&
        lexicalText.isNotEmpty) {
      final lexical = await _applyFilters(
        await _lexicalDocuments(lexicalText, effectiveFilters, candidateLimit),
        effectiveFilters,
      );
      _mergeRank(ranked, lexical, _RankChannel.lexical);
    }

    Object? semanticError;
    final provider = embeddingProvider;
    if (provider != null &&
        query.trim().isNotEmpty &&
        (mode == MemorySearchMode.hybrid ||
            mode == MemorySearchMode.semantic)) {
      try {
        final semantic = await _semanticDocuments(
          query,
          effectiveFilters,
          candidateLimit,
          provider,
        );
        final filtered = await _applyFilters(
          semantic.map((item) => item.document).toList(),
          effectiveFilters,
        );
        final similarityById = {
          for (final item in semantic) item.document.key: item.similarity,
        };
        _mergeRank(
          ranked,
          filtered,
          _RankChannel.semantic,
          similarities: similarityById,
        );
      } catch (error) {
        semanticError = error;
      }
    }

    if ((mode == MemorySearchMode.hybrid ||
            mode == MemorySearchMode.temporal) &&
        effectiveFilters.start != null &&
        effectiveFilters.end != null) {
      final timed = await _applyFilters(
        await _temporalDocuments(effectiveFilters, candidateLimit),
        effectiveFilters,
      );
      _mergeRank(ranked, timed, _RankChannel.temporal);
    }

    final ordered =
        ranked.values.toList()..sort((a, b) {
          final score = b.score.compareTo(a.score);
          return score != 0
              ? score
              : b.document.endedAt.compareTo(a.document.endedAt);
        });
    final selected = ordered.take(limit).toList();
    return MemorySearchResult(
      evidence: [
        for (final item in selected)
          item.toEvidence(resolvedTemporal.confidence),
      ],
      temporal: temporal,
      semanticError: semanticError,
      matches: [
        for (final item in selected)
          if (item.document.episode != null)
            MemoryMatch(
              episode: item.document.episode!,
              score: item.score,
              lexical: item.ranks.containsKey(_RankChannel.lexical),
              semantic: item.ranks.containsKey(_RankChannel.semantic),
            ),
      ],
    );
  }

  Future<int> _indexItems<T>(
    Iterable<T> items, {
    required String Function(T item) key,
    required String Function(T item) content,
    required Future<void> Function(T item, List<double> vector) save,
    required Map<String, Object> failures,
    required EmbeddingProvider provider,
  }) async {
    var indexed = 0;
    for (final item in items) {
      try {
        final vector = await provider.embed(content(item));
        await save(item, vector);
        indexed++;
      } catch (error) {
        failures[key(item)] = error;
      }
    }
    return indexed;
  }

  Future<_ResolvedTemporal> _resolveTemporal(
    TemporalQuery temporal,
    MemorySearchFilters filters,
  ) async {
    if (temporal.hasRange || temporal.relation == null) {
      return _ResolvedTemporal(
        start: temporal.start,
        end: temporal.end,
        confidence: temporal.confidence,
      );
    }
    final anchor = temporal.anchor?.trim() ?? '';
    if (anchor.isEmpty) {
      return _ResolvedTemporal(confidence: temporal.confidence);
    }
    final anchorFilters = filters.withoutInterval();
    final anchorDocuments = await _applyFilters(
      await _lexicalDocuments(anchor, anchorFilters, 20),
      anchorFilters,
    );
    if (anchorDocuments.isEmpty) {
      return _ResolvedTemporal(confidence: temporal.confidence);
    }
    anchorDocuments.sort((a, b) => b.endedAt.compareTo(a.endedAt));
    final event = anchorDocuments.first;
    final eventEnd =
        event.endedAt.isAfter(event.startedAt)
            ? event.endedAt
            : event.startedAt.add(defaultTemporalPointWindow);
    return switch (temporal.relation!) {
      TemporalRelation.before => _ResolvedTemporal(
        start: event.startedAt.subtract(defaultTemporalAnchorWindow),
        end: event.startedAt,
        confidence: temporal.confidence,
      ),
      TemporalRelation.during ||
      TemporalRelation.lastOccurrence => _ResolvedTemporal(
        start: event.startedAt,
        end: eventEnd,
        confidence: temporal.confidence,
      ),
    };
  }

  MemorySearchFilters? _effectiveFilters(
    MemorySearchFilters filters,
    _ResolvedTemporal temporal,
  ) {
    final starts = [filters.start, temporal.start].whereType<DateTime>();
    final ends = [filters.end, temporal.end].whereType<DateTime>();
    final start =
        starts.isEmpty ? null : starts.reduce((a, b) => a.isAfter(b) ? a : b);
    final end =
        ends.isEmpty ? null : ends.reduce((a, b) => a.isBefore(b) ? a : b);
    if (start != null && end != null && !start.isBefore(end)) return null;
    return filters.withInterval(start, end);
  }

  Future<List<_MemoryDocument>> _lexicalDocuments(
    String query,
    MemorySearchFilters filters,
    int limit,
  ) async {
    final documents = <_MemoryDocument>[];
    if (_includes(filters, MemoryEvidenceSource.episode)) {
      documents.addAll(
        _sourceRanks(
          (await episodes.searchKeyword(
            query,
            start: filters.start,
            end: filters.end,
            limit: limit,
          )).map(_episodeDocument),
        ),
      );
    }
    final summaryRepository = summaries;
    if (summaryRepository != null && _includesSummaries(filters)) {
      documents.addAll(
        _sourceRanks(
          (await summaryRepository.searchKeyword(
            query,
            start: filters.start,
            end: filters.end,
            limit: limit,
          )).map(_summaryDocument),
        ),
      );
    }
    final conversationRepository = conversations;
    if (conversationRepository != null &&
        _includes(filters, MemoryEvidenceSource.conversation)) {
      documents.addAll(
        _sourceRanks(
          (await conversationRepository.search(
            query,
            start: filters.start,
            end: filters.end,
            limit: limit,
          )).map(_conversationDocument),
        ),
      );
    }
    final snippetRepository = snippets;
    if (snippetRepository != null &&
        _includes(filters, MemoryEvidenceSource.snippet)) {
      documents.addAll(
        _sourceRanks(
          (await snippetRepository.searchByKeyword(
            query,
            start: filters.start,
            end: filters.end,
            limit: limit,
          )).map(_snippetDocument),
        ),
      );
    }
    return _deduplicate(documents);
  }

  Future<List<_SemanticDocument>> _semanticDocuments(
    String query,
    MemorySearchFilters filters,
    int limit,
    EmbeddingProvider provider,
  ) async {
    final providerId = await embeddingProviderFingerprint(provider);
    var entries =
        (await _vectorEntries(
          providerId,
        )).where((entry) => _includesVector(filters, entry.key)).toList();
    if (_requiresVectorPrefilter(filters)) {
      final documents = await _applyFilters(
        await _documentsByKeys(entries.map((entry) => entry.key)),
        filters,
      );
      final allowed = documents.map((document) => document.key).toSet();
      entries = entries.where((entry) => allowed.contains(entry.key)).toList();
    }
    // ponytail: brute-force in-memory search is within the 50k latency gate;
    // replace with an ANN index only when the benchmark exceeds it.
    final matches = vectorIndex.search(
      await provider.embed(query),
      entries,
      limit: limit,
      minScore: minSemanticSimilarity,
    );
    final documents = await _documentsByKeys(matches.map((item) => item.key));
    final byKey = {for (final document in documents) document.key: document};
    return [
      for (final match in matches)
        if (byKey[match.key] != null)
          _SemanticDocument(
            document: byKey[match.key]!,
            similarity: match.score,
          ),
    ];
  }

  Future<List<VectorEntry<String>>> _vectorEntries(String providerId) async {
    final cached = _cachedVectors;
    final cachedAt = _vectorsCachedAt;
    if (cached != null &&
        _cachedVectorProviderId == providerId &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < vectorCacheTtl) {
      return cached;
    }
    final entries = <VectorEntry<String>>[
      for (final item in await episodes.vectors(providerId))
        VectorEntry(key: 'episode:${item.id}', vector: item.embedding),
    ];
    final summaryRepository = summaries;
    if (summaryRepository != null) {
      entries.addAll(
        (await summaryRepository.vectors(providerId)).map(
          (item) =>
              VectorEntry(key: 'summary:${item.id}', vector: item.embedding),
        ),
      );
    }
    final conversationRepository = conversations;
    if (conversationRepository != null) {
      entries.addAll(
        (await conversationRepository.vectors(providerId)).map(
          (item) => VectorEntry(
            key: 'conversation:${item.id}',
            vector: item.embedding,
          ),
        ),
      );
    }
    final snippetRepository = snippets;
    if (snippetRepository != null) {
      entries.addAll(
        (await snippetRepository.vectors(providerId)).map(
          (item) =>
              VectorEntry(key: 'snippet:${item.id}', vector: item.embedding),
        ),
      );
    }
    _cachedVectorProviderId = providerId;
    _vectorsCachedAt = DateTime.now();
    _cachedVectors = entries;
    return entries;
  }

  bool _includesVector(MemorySearchFilters filters, String key) {
    final separator = key.indexOf(':');
    if (separator < 1) return false;
    return switch (key.substring(0, separator)) {
      'episode' => _includes(filters, MemoryEvidenceSource.episode),
      'summary' => _includesSummaries(filters),
      'conversation' => _includes(filters, MemoryEvidenceSource.conversation),
      'snippet' => _includes(filters, MemoryEvidenceSource.snippet),
      _ => false,
    };
  }

  bool _requiresVectorPrefilter(MemorySearchFilters filters) =>
      filters.applications.isNotEmpty ||
      filters.modalities.isNotEmpty ||
      filters.projects.isNotEmpty ||
      filters.start != null ||
      filters.end != null ||
      filters.sources.contains(MemoryEvidenceSource.summary) !=
          filters.sources.contains(MemoryEvidenceSource.durableMemory);

  void _invalidateVectorCache() {
    _cachedVectorProviderId = null;
    _vectorsCachedAt = null;
    _cachedVectors = null;
  }

  Future<List<_MemoryDocument>> _temporalDocuments(
    MemorySearchFilters filters,
    int limit,
  ) async {
    final start = filters.start;
    final end = filters.end;
    if (start == null || end == null) return const [];
    final documents = <_MemoryDocument>[];
    if (_includes(filters, MemoryEvidenceSource.episode)) {
      documents.addAll(
        (await episodes.between(
          start,
          end,
          limit: limit,
        )).map(_episodeDocument),
      );
    }
    final summaryRepository = summaries;
    if (summaryRepository != null && _includesSummaries(filters)) {
      documents.addAll(
        (await summaryRepository.between(
          start,
          end,
          limit: limit,
        )).map(_summaryDocument),
      );
    }
    final conversationRepository = conversations;
    if (conversationRepository != null &&
        _includes(filters, MemoryEvidenceSource.conversation)) {
      documents.addAll(
        (await conversationRepository.between(
          start,
          end,
          limit: limit,
        )).map(_conversationDocument),
      );
    }
    final snippetRepository = snippets;
    if (snippetRepository != null &&
        _includes(filters, MemoryEvidenceSource.snippet)) {
      documents.addAll(
        (await snippetRepository.between(
          start,
          end,
          limit: limit,
        )).map(_snippetDocument),
      );
    }
    documents.sort((a, b) => b.endedAt.compareTo(a.endedAt));
    return _deduplicate(documents).take(limit).toList();
  }

  Future<List<_MemoryDocument>> _documentsByKeys(Iterable<String> keys) async {
    final grouped = <MemoryEvidenceSource, List<int>>{};
    for (final key in keys) {
      final parts = key.split(':');
      if (parts.length != 2) continue;
      MemoryEvidenceSource? source;
      for (final candidate in MemoryEvidenceSource.values) {
        if (candidate.name == parts.first) source = candidate;
      }
      final id = int.tryParse(parts.last);
      if (source == null || id == null) continue;
      grouped.putIfAbsent(source, () => []).add(id);
    }
    final documents = <_MemoryDocument>[];
    final episodeIds = grouped[MemoryEvidenceSource.episode] ?? const [];
    documents.addAll((await episodes.byIds(episodeIds)).map(_episodeDocument));
    final summaryRepository = summaries;
    if (summaryRepository != null) {
      final summaryIds = [
        ...grouped[MemoryEvidenceSource.summary] ?? const <int>[],
        ...grouped[MemoryEvidenceSource.durableMemory] ?? const <int>[],
      ];
      documents.addAll(
        (await summaryRepository.byIds(summaryIds)).map(_summaryDocument),
      );
    }
    final conversationRepository = conversations;
    if (conversationRepository != null) {
      documents.addAll(
        (await conversationRepository.byIds(
          grouped[MemoryEvidenceSource.conversation] ?? const [],
        )).map(_conversationDocument),
      );
    }
    final snippetRepository = snippets;
    if (snippetRepository != null) {
      documents.addAll(
        (await snippetRepository.byIds(
          grouped[MemoryEvidenceSource.snippet] ?? const [],
        )).map(_snippetDocument),
      );
    }
    return documents;
  }

  Future<List<_MemoryDocument>> _applyFilters(
    Iterable<_MemoryDocument> documents,
    MemorySearchFilters filters,
  ) async {
    final selected = <_MemoryDocument>[];
    for (var document in documents) {
      if (!_includes(filters, document.source) ||
          !_overlaps(document, filters) ||
          !_matchesProjects(document, filters.projects)) {
        continue;
      }
      if (filters.applications.isNotEmpty &&
          document.applications.isNotEmpty &&
          !_matchesNames(document.applications, filters.applications)) {
        continue;
      }
      final needsActivityMetadata =
          (filters.applications.isNotEmpty && document.applications.isEmpty) ||
          (filters.modalities.isNotEmpty &&
              !_matchesModalities(document.modalities, filters.modalities));
      if (needsActivityMetadata) {
        document = await _hydrateActivityMetadata(document, filters);
      }
      if (!_matchesNames(document.applications, filters.applications) ||
          !_matchesModalities(document.modalities, filters.modalities)) {
        continue;
      }
      selected.add(document);
    }
    return _deduplicate(selected);
  }

  Future<_MemoryDocument> _hydrateActivityMetadata(
    _MemoryDocument document,
    MemorySearchFilters filters,
  ) async {
    if (filters.applications.isEmpty && filters.modalities.isEmpty) {
      return document;
    }
    final activityRepository = activities;
    if (activityRepository == null ||
        (document.source != MemoryEvidenceSource.episode &&
            document.source != MemoryEvidenceSource.summary &&
            document.source != MemoryEvidenceSource.durableMemory)) {
      return document;
    }
    final captured =
        document.sourceActivityIds.isNotEmpty
            ? await activityRepository.byIds(document.sourceActivityIds)
            : await activityRepository.between(
              document.startedAt,
              document.endedAt,
            );
    return document.copyWith(
      applications:
          {
            ...document.applications,
            ...captured.map((item) => item.appName),
          }.toList(),
      modalities: {
        ...document.modalities,
        ...captured.expand(_activityModalities),
      },
    );
  }

  Iterable<MemoryModality> _activityModalities(Activity activity) sync* {
    yield MemoryModality.metadata;
    if (_hasText(activity.capturedText) ||
        _hasText(activity.capturedScreenText)) {
      yield MemoryModality.vision;
    }
    if (_hasText(activity.capturedClipboard)) yield MemoryModality.clipboard;
    if (_hasText(activity.capturedUrl)) yield MemoryModality.browser;
    if (_hasText(activity.capturedAudioText)) yield MemoryModality.audio;
  }

  void _mergeRank(
    Map<String, _RankedDocument> ranked,
    Iterable<_MemoryDocument> documents,
    _RankChannel channel, {
    Map<String, double> similarities = const {},
  }) {
    var rank = 1;
    for (final document in documents) {
      final item = ranked.putIfAbsent(
        document.key,
        () => _RankedDocument(document),
      );
      item.ranks.putIfAbsent(
        channel,
        () =>
            channel == _RankChannel.lexical
                ? document.sourceRank ?? rank
                : rank,
      );
      final similarity = similarities[document.key];
      if (similarity != null) item.semanticSimilarity = similarity;
      rank++;
    }
  }

  bool _includes(MemorySearchFilters filters, MemoryEvidenceSource source) =>
      filters.sources.isEmpty || filters.sources.contains(source);

  bool _includesSummaries(MemorySearchFilters filters) =>
      _includes(filters, MemoryEvidenceSource.summary) ||
      _includes(filters, MemoryEvidenceSource.durableMemory);

  bool _overlaps(_MemoryDocument document, MemorySearchFilters filters) =>
      (filters.start == null || document.endedAt.isAfter(filters.start!)) &&
      (filters.end == null || document.startedAt.isBefore(filters.end!));

  bool _matchesNames(Iterable<String> values, Set<String> selected) {
    if (selected.isEmpty) return true;
    final normalized = selected.map(_normalize).toSet();
    return values.map(_normalize).any(normalized.contains);
  }

  bool _matchesProjects(_MemoryDocument document, Set<String> selected) {
    if (selected.isEmpty) return true;
    final projectNames = document.projects.map(_normalize).toSet();
    final haystack = _normalize(
      '${document.title}\n${document.content}\n${document.projects.join(' ')}',
    );
    return selected
        .map(_normalize)
        .any(
          (project) =>
              projectNames.contains(project) || haystack.contains(project),
        );
  }

  bool _matchesModalities(
    Set<MemoryModality> values,
    Set<MemoryModality> selected,
  ) => selected.isEmpty || values.any(selected.contains);

  _MemoryDocument _episodeDocument(MemoryEpisode episode) => _MemoryDocument(
    key: 'episode:${episode.id}',
    source: MemoryEvidenceSource.episode,
    sourceId: episode.id,
    title: episode.title,
    content: _episodeContent(episode),
    startedAt: episode.startedAt,
    endedAt: episode.endedAt,
    applications: episode.applications,
    modalities: const {MemoryModality.metadata},
    projects: _projects([...episode.entities, ...episode.urls]),
    sourceActivityIds: episode.sourceActivityIds,
    episode: episode,
  );

  _MemoryDocument _summaryDocument(ActivitySummary summary) => _MemoryDocument(
    key: 'summary:${summary.id}',
    source:
        summary.kind == SummaryKind.durable
            ? MemoryEvidenceSource.durableMemory
            : MemoryEvidenceSource.summary,
    sourceId: summary.id,
    title: summary.kind.name,
    content: summary.content,
    startedAt: summary.periodStart,
    endedAt: summary.periodEnd,
    modalities: const {MemoryModality.metadata},
    projects: _projects([summary.content]),
  );

  _MemoryDocument _conversationDocument(ConversationMessage message) =>
      _MemoryDocument(
        key: 'conversation:${message.id}',
        source: MemoryEvidenceSource.conversation,
        sourceId: message.id,
        title: 'Conversa ${message.conversationId} · ${message.role.name}',
        content: message.content,
        startedAt: message.createdAt,
        endedAt: message.createdAt,
        modalities: const {MemoryModality.metadata},
        projects: _projects([message.content]),
      );

  _MemoryDocument _snippetDocument(Snippet snippet) => _MemoryDocument(
    key: 'snippet:${snippet.id}',
    source: MemoryEvidenceSource.snippet,
    sourceId: snippet.id,
    title: snippet.title,
    content: snippet.content,
    startedAt: snippet.createdAt,
    endedAt: snippet.updatedAt,
    modalities: const {MemoryModality.metadata},
    projects: _projects([...snippet.tags, snippet.title]),
  );

  String _episodeContent(MemoryEpisode episode) => [
    episode.summary,
    ...episode.decisions,
    ...episode.actionItems,
    ...episode.technologies,
    ...episode.topics,
    ...episode.entities,
  ].join('\n');

  List<String> _projects(Iterable<String> values) {
    final projects = <String>{};
    for (final value in values) {
      final tagged = RegExp(
        r'\bproject:([^\s,;]+)',
        caseSensitive: false,
      ).allMatches(value);
      projects.addAll(tagged.map((match) => match.group(1)!).where(_hasText));
      final github = RegExp(
        r'github\.com/([^/\s]+)/([^/#?\s]+)',
        caseSensitive: false,
      ).allMatches(value);
      projects.addAll(
        github.map((match) => '${match.group(1)}/${match.group(2)}'),
      );
    }
    return projects.toList()..sort();
  }

  List<_MemoryDocument> _deduplicate(Iterable<_MemoryDocument> documents) {
    final byKey = <String, _MemoryDocument>{};
    for (final document in documents) {
      byKey.putIfAbsent(document.key, () => document);
    }
    return byKey.values.toList();
  }

  List<_MemoryDocument> _sourceRanks(Iterable<_MemoryDocument> documents) {
    var rank = 1;
    return [
      for (final document in documents) document.copyWith(sourceRank: rank++),
    ];
  }

  String _lexicalText(String query, TemporalQuery temporal) {
    final anchor = temporal.anchor;
    if (anchor != null && anchor.isNotEmpty) return anchor;
    final tokens =
        _normalize(query)
            .split(RegExp(r'[^a-z0-9_+#.-]+'))
            .where((token) => token.length >= 2)
            .where((token) => !_queryStopWords.contains(token))
            .where((token) => !RegExp(r'^\d{1,4}$').hasMatch(token))
            .take(12)
            .toList();
    return tokens.join(' ');
  }
}

enum _RankChannel { lexical, semantic, temporal }

class _RankedDocument {
  _RankedDocument(this.document);

  final _MemoryDocument document;
  final Map<_RankChannel, int> ranks = {};
  double? semanticSimilarity;

  double get score => ranks.values.fold(
    0,
    (total, rank) => total + 1 / (reciprocalRankFusionOffset + rank),
  );

  MemorySearchEvidence toEvidence(double temporalConfidence) {
    final reasons = <String>[];
    final lexicalRank = ranks[_RankChannel.lexical];
    if (lexicalRank != null) {
      reasons.add('Correspondência lexical #$lexicalRank');
    }
    final semanticRank = ranks[_RankChannel.semantic];
    if (semanticRank != null) {
      final similarity = semanticSimilarity;
      reasons.add(
        similarity == null
            ? 'Correspondência semântica #$semanticRank'
            : 'Correspondência semântica #$semanticRank '
                '(${similarity.toStringAsFixed(3)})',
      );
    }
    final temporalRank = ranks[_RankChannel.temporal];
    if (temporalRank != null) {
      reasons.add(
        'Correspondência temporal #$temporalRank '
        '(confiança ${temporalConfidence.toStringAsFixed(2)})',
      );
    }
    return MemorySearchEvidence(
      id: document.key,
      source: document.source,
      sourceId: document.sourceId,
      title: document.title,
      content: document.content,
      startedAt: document.startedAt,
      endedAt: document.endedAt,
      score: score,
      matchReasons: reasons,
      applications: document.applications,
      modalities: document.modalities,
      projects: document.projects,
      semanticSimilarity: semanticSimilarity,
    );
  }
}

class _MemoryDocument {
  const _MemoryDocument({
    required this.key,
    required this.source,
    required this.sourceId,
    required this.title,
    required this.content,
    required this.startedAt,
    required this.endedAt,
    this.applications = const [],
    this.modalities = const {},
    this.projects = const [],
    this.sourceActivityIds = const [],
    this.episode,
    this.sourceRank,
  });

  final String key;
  final MemoryEvidenceSource source;
  final int sourceId;
  final String title;
  final String content;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<String> applications;
  final Set<MemoryModality> modalities;
  final List<String> projects;
  final List<int> sourceActivityIds;
  final MemoryEpisode? episode;
  final int? sourceRank;

  _MemoryDocument copyWith({
    List<String>? applications,
    Set<MemoryModality>? modalities,
    int? sourceRank,
  }) => _MemoryDocument(
    key: key,
    source: source,
    sourceId: sourceId,
    title: title,
    content: content,
    startedAt: startedAt,
    endedAt: endedAt,
    applications: applications ?? this.applications,
    modalities: modalities ?? this.modalities,
    projects: projects,
    sourceActivityIds: sourceActivityIds,
    episode: episode,
    sourceRank: sourceRank ?? this.sourceRank,
  );
}

class _SemanticDocument {
  const _SemanticDocument({required this.document, required this.similarity});

  final _MemoryDocument document;
  final double similarity;
}

class _ResolvedTemporal {
  const _ResolvedTemporal({this.start, this.end, required this.confidence});

  final DateTime? start;
  final DateTime? end;
  final double confidence;
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áàâãä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòôõö]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll('ç', 'c');

const _queryStopWords = {
  'about',
  'ago',
  'and',
  'antes',
  'around',
  'as',
  'at',
  'da',
  'das',
  'de',
  'do',
  'dos',
  'during',
  'durante',
  'eu',
  'fiz',
  'ha',
  'hoje',
  'how',
  'in',
  'last',
  'me',
  'mes',
  'month',
  'na',
  'nas',
  'no',
  'nos',
  'of',
  'on',
  'ontem',
  'os',
  'passada',
  'passado',
  'past',
  'por',
  'que',
  'semana',
  'the',
  'this',
  'time',
  'today',
  'ultima',
  'ultimo',
  'vez',
  'what',
  'week',
  'when',
  'yesterday',
};
