import 'package:kangoos_core/kangoos_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

const deepStudyMessageMarker = '<!-- kangoos:deep-study -->';

enum TimelineItemType {
  event,
  episode,
  summary,
  manualMemory,
  conversation,
  deepStudyReport,
}

class TimelineItem {
  const TimelineItem({
    required this.key,
    required this.type,
    required this.sourceId,
    required this.title,
    required this.content,
    required this.startedAt,
    required this.endedAt,
    this.applications = const [],
    this.modalities = const {},
    this.projects = const [],
    this.favorite = false,
  });

  final String key;
  final TimelineItemType type;
  final int sourceId;
  final String title;
  final String content;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<String> applications;
  final Set<MemoryModality> modalities;
  final List<String> projects;
  final bool favorite;

  TimelineItem copyWith({bool? favorite}) => TimelineItem(
    key: key,
    type: type,
    sourceId: sourceId,
    title: title,
    content: content,
    startedAt: startedAt,
    endedAt: endedAt,
    applications: applications,
    modalities: modalities,
    projects: projects,
    favorite: favorite ?? this.favorite,
  );
}

class TimelineQuery {
  const TimelineQuery({
    this.text = '',
    this.mode = MemorySearchMode.lexical,
    this.filters = const MemorySearchFilters(),
    this.types = const {},
    this.favoritesOnly = false,
  });

  final String text;
  final MemorySearchMode mode;
  final MemorySearchFilters filters;
  final Set<TimelineItemType> types;
  final bool favoritesOnly;
}

class TimelineService {
  TimelineService({required this.memory, required this.conversations});

  final MemoryService memory;
  final ConversationRepository conversations;

  static const _favoritesKey = 'timeline_favorites';

  Future<List<TimelineItem>> search(TimelineQuery query) async {
    final favorites = await _favorites();
    final items = <TimelineItem>[];
    final requestedSources = _requestedSources(query.types);
    final selectedSources =
        query.filters.sources.isEmpty
            ? requestedSources
            : requestedSources.isEmpty
            ? query.filters.sources
            : requestedSources.intersection(query.filters.sources);
    final includesMemory =
        query.types.isEmpty ||
        query.types.any((type) => type != TimelineItemType.event);
    if (includesMemory &&
        (requestedSources.isEmpty || selectedSources.isNotEmpty)) {
      final now = DateTime.now();
      final filters = query.filters.copyWith(
        sources: selectedSources,
        start: query.filters.start ?? DateTime.fromMillisecondsSinceEpoch(0),
        end: query.filters.end ?? now.add(const Duration(minutes: 1)),
      );
      final result = await memory.searchMemory(
        query.text,
        limit: 200,
        mode:
            query.text.trim().isEmpty ? MemorySearchMode.temporal : query.mode,
        filters: filters,
      );
      if (query.mode == MemorySearchMode.semantic &&
          result.semanticError != null &&
          result.evidence.isEmpty) {
        throw StateError('Busca semântica indisponível: ${result.semanticError}');
      }
      items.addAll(
        result.evidence
            .map(_fromEvidence)
            .where((item) => _includesType(item.type, query.types)),
      );
    }

    if (query.types.contains(TimelineItemType.event) ||
        (query.types.isEmpty && query.filters.sources.isEmpty)) {
      items.addAll(await _events(query));
    }

    final selected =
        items
            .map(
              (item) => item.copyWith(favorite: favorites.contains(item.key)),
            )
            .where((item) => !query.favoritesOnly || item.favorite)
            .toList()
          ..sort((left, right) => right.endedAt.compareTo(left.endedAt));
    return selected;
  }

  Future<List<Activity>> relatedActivities(TimelineItem item) async {
    if (item.type == TimelineItemType.episode) {
      final episode = await memory.getEpisode(item.sourceId);
      if (episode != null && episode.sourceActivityIds.isNotEmpty) {
        return memory.activities.byIds(episode.sourceActivityIds);
      }
    }
    return memory.between(
      item.startedAt.subtract(const Duration(minutes: 15)),
      item.endedAt.add(const Duration(minutes: 15)),
      limit: 30,
    );
  }

  Future<void> delete(TimelineItem item) async {
    switch (item.type) {
      case TimelineItemType.event:
        await memory.deleteActivity(item.sourceId);
      case TimelineItemType.episode:
        await memory.forgetEpisode(item.sourceId);
      case TimelineItemType.summary || TimelineItemType.manualMemory:
        await memory.forgetSummary(item.sourceId);
      case TimelineItemType.conversation || TimelineItemType.deepStudyReport:
        await conversations.deleteMessage(item.sourceId);
    }
    final favorites =
        await _favorites()
          ..remove(item.key);
    await _saveFavorites(favorites);
  }

  Future<bool> toggleFavorite(TimelineItem item) async {
    final favorites = await _favorites();
    final selected = !favorites.remove(item.key);
    if (selected) favorites.add(item.key);
    await _saveFavorites(favorites);
    return selected;
  }

  Future<List<TimelineItem>> _events(TimelineQuery query) async {
    final filters = query.filters;
    final activities =
        query.text.trim().isEmpty
            ? await memory.between(
              filters.start ?? DateTime.fromMillisecondsSinceEpoch(0),
              filters.end ?? DateTime.now().add(const Duration(minutes: 1)),
              limit: 200,
            )
            : await memory.search(
              query.text,
              start: filters.start,
              end: filters.end,
              limit: 200,
            );
    return activities
        .where((item) => _matchesActivity(item, filters))
        .map(_fromActivity)
        .toList();
  }

  bool _matchesActivity(Activity activity, MemorySearchFilters filters) {
    final selectedApplications =
        filters.applications.map((item) => item.toLowerCase()).toSet();
    if (selectedApplications.isNotEmpty &&
        !selectedApplications.contains(activity.appName.toLowerCase())) {
      return false;
    }
    final modalities = _activityModalities(activity);
    if (filters.modalities.isNotEmpty &&
        !modalities.any(filters.modalities.contains)) {
      return false;
    }
    if (filters.projects.isNotEmpty) {
      final content =
          [
            activity.appName,
            activity.windowTitle,
            activity.capturedText,
            activity.capturedUrl,
          ].whereType<String>().join('\n').toLowerCase();
      if (!filters.projects.any(
        (project) => content.contains(project.toLowerCase()),
      )) {
        return false;
      }
    }
    return true;
  }

  TimelineItem _fromActivity(Activity activity) => TimelineItem(
    key: 'event:${activity.id}',
    type: TimelineItemType.event,
    sourceId: activity.id,
    title:
        activity.windowTitle.isEmpty ? activity.appName : activity.windowTitle,
    content: [
      activity.capturedText,
      activity.capturedClipboard,
      activity.capturedScreenText,
      activity.capturedAudioText,
      activity.capturedUrl,
    ].whereType<String>().where((item) => item.trim().isNotEmpty).join('\n'),
    startedAt: activity.capturedAt,
    endedAt: activity.capturedAt,
    applications: [activity.appName],
    modalities: _activityModalities(activity),
  );

  TimelineItem _fromEvidence(MemorySearchEvidence evidence) {
    final deepStudy = evidence.content.startsWith(deepStudyMessageMarker);
    final type = switch (evidence.source) {
      MemoryEvidenceSource.episode => TimelineItemType.episode,
      MemoryEvidenceSource.durableMemory => TimelineItemType.manualMemory,
      MemoryEvidenceSource.summary =>
        evidence.title == SummaryKind.manual.name
            ? TimelineItemType.manualMemory
            : TimelineItemType.summary,
      MemoryEvidenceSource.conversation =>
        deepStudy
            ? TimelineItemType.deepStudyReport
            : TimelineItemType.conversation,
      MemoryEvidenceSource.snippet => TimelineItemType.manualMemory,
    };
    return TimelineItem(
      key: '${type.name}:${evidence.sourceId}',
      type: type,
      sourceId: evidence.sourceId,
      title: _title(type, evidence.title, evidence.content),
      content:
          deepStudy
              ? evidence.content.substring(deepStudyMessageMarker.length).trim()
              : evidence.content,
      startedAt: evidence.startedAt,
      endedAt: evidence.endedAt,
      applications: evidence.applications,
      modalities: evidence.modalities,
      projects: evidence.projects,
    );
  }

  Set<MemoryEvidenceSource> _requestedSources(Set<TimelineItemType> types) {
    if (types.isEmpty) {
      return {
        MemoryEvidenceSource.episode,
        MemoryEvidenceSource.summary,
        MemoryEvidenceSource.durableMemory,
        MemoryEvidenceSource.conversation,
      };
    }
    return {
      if (types.contains(TimelineItemType.episode))
        MemoryEvidenceSource.episode,
      if (types.contains(TimelineItemType.summary))
        MemoryEvidenceSource.summary,
      if (types.contains(TimelineItemType.manualMemory))
        MemoryEvidenceSource.durableMemory,
      if (types.contains(TimelineItemType.conversation) ||
          types.contains(TimelineItemType.deepStudyReport))
        MemoryEvidenceSource.conversation,
    };
  }

  Future<Set<String>> _favorites() async =>
      (await SharedPreferences.getInstance())
          .getStringList(_favoritesKey)
          ?.toSet() ??
      <String>{};

  Future<void> _saveFavorites(Set<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, favorites.toList()..sort());
  }
}

bool _includesType(TimelineItemType type, Set<TimelineItemType> selected) =>
    selected.isEmpty || selected.contains(type);

Set<MemoryModality> _activityModalities(Activity activity) => {
  MemoryModality.metadata,
  if (activity.capturedScreenText?.trim().isNotEmpty ?? false)
    MemoryModality.vision,
  if (activity.capturedClipboard?.trim().isNotEmpty ?? false)
    MemoryModality.clipboard,
  if (activity.capturedUrl?.trim().isNotEmpty ?? false) MemoryModality.browser,
  if (activity.capturedAudioText?.trim().isNotEmpty ?? false)
    MemoryModality.audio,
};

String _title(TimelineItemType type, String title, String content) {
  if (type == TimelineItemType.deepStudyReport) {
    final firstLine = content
        .split('\n')
        .firstWhere(
          (line) => line.trim().isNotEmpty,
          orElse: () => 'DeepStudy',
        );
    return firstLine.replaceFirst(RegExp(r'^#+\s*'), '');
  }
  return switch (type) {
    TimelineItemType.episode => title,
    TimelineItemType.summary => 'Resumo',
    TimelineItemType.manualMemory => 'Memória manual',
    TimelineItemType.conversation => 'Conversa',
    TimelineItemType.event => title,
    TimelineItemType.deepStudyReport => 'DeepStudy',
  };
}
