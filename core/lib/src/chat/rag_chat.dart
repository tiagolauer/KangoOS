import '../activity/activity_span.dart';
import '../database/database.dart';
import '../llm/llm_provider.dart';
import '../memory/memory_service.dart';
import '../memory/memory_query_engine.dart';
import '../memory/memory_agent.dart';
import '../snippets/snippet_service.dart';
import 'temporal_query.dart';

class RagChat {
  RagChat({
    required this.snippets,
    required this.memory,
    this.agent,
    this.maxContextSnippets = 5,
    this.maxContextActivities = 30,
    this.maxContextSummaries = 5,
    this.maxHistoryMessages = 20,
    this.onSemanticSearchError,
  });

  final SnippetService snippets;
  final MemoryService memory;
  final MemoryAgent? agent;
  final int maxContextSnippets;
  final int maxContextActivities;
  final int maxContextSummaries;
  final int maxHistoryMessages;

  final void Function(Object error)? onSemanticSearchError;

  static const _queryBoundarySlack = Duration(seconds: 1);

  Future<List<Snippet>> retrieveContext(String query) async {
    try {
      final matches = await snippets.search(
        query,
        mode: SnippetSearchMode.semantic,
        limit: maxContextSnippets,
      );
      if (matches.isNotEmpty) return matches;
    } catch (error) {
      onSemanticSearchError?.call(error);
    }
    return snippets.search(query, limit: maxContextSnippets);
  }

  Future<List<Activity>> retrieveActivity(DateRange range) async {
    final activities = await memory.between(
      range.start,
      range.end.add(_queryBoundarySlack),
      limit: maxContextActivities,
    );
    return activities.reversed.toList();
  }

  Future<List<ActivitySummary>> retrieveRecentSummaries() =>
      memory.recentSummaries(limit: maxContextSummaries);

  Future<MemorySearchResult> retrieveMemory(String query) =>
      memory.searchEpisodes(query, limit: maxContextSummaries);

  String buildSystemPrompt(List<Snippet> snippets, List<Activity> activities,
      List<ActivitySummary> summaries, DateRange activityRange,
      [List<MemoryEpisode> episodes = const [], String? investigationContext]) {
    final buffer = StringBuffer(
      'Você é o assistente do KangoOS. Responda sempre em português do Brasil '
      '(PT-BR), mesmo que a pergunta ou o contexto estejam em outro idioma. '
      'Preserve código, comandos, nomes próprios e identificadores no idioma '
      'original. Use os snippets e a atividade capturada abaixo quando forem '
      'relevantes. Se nada for relevante, deixe isso claro e responda com base '
      'no seu conhecimento geral.',
    );

    for (final snippet in snippets) {
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln('Title: ${snippet.title}');
      if (snippet.language != null && snippet.language!.isNotEmpty) {
        buffer.writeln('Language: ${snippet.language}');
      }
      buffer.writeln(snippet.content);
    }

    if (episodes.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('--- Structured memory episodes ---');
      for (final episode in episodes) {
        buffer.writeln(
          '[${episode.startedAt.toLocal()} - ${episode.endedAt.toLocal()}] '
          '${episode.title}: ${episode.summary}',
        );
        if (episode.decisions.isNotEmpty) {
          buffer.writeln('Decisões: ${episode.decisions.join('; ')}');
        }
        if (episode.actionItems.isNotEmpty) {
          buffer.writeln('Pendências: ${episode.actionItems.join('; ')}');
        }
        if (episode.technologies.isNotEmpty) {
          buffer.writeln('Tecnologias: ${episode.technologies.join(', ')}');
        }
        if (episode.entities.isNotEmpty) {
          buffer.writeln('Entidades relacionadas: ${episode.entities.join(', ')}');
        }
      }
    }

    if (summaries.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('--- Recent activity summaries ---');
      for (final summary in summaries) {
        buffer.writeln(
            '[${summary.kind.name} ${_time(summary.periodStart)}-${_time(summary.periodEnd)}] '
            '${summary.content}');
      }
    }

    if (activities.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(
          '--- Captured activity (${_describeRange(activityRange)}) ---');
      final spans = {
        for (final span in activitySpans(activities.reversed.toList(),
            until: activityRange.end))
          span.activity.id: span.duration,
      };
      for (final activity in activities) {
        buffer.write('[${_time(activity.capturedAt)} '
            '${formatActivityDuration(spans[activity.id] ?? Duration.zero)}] '
            '${activity.appName} — ${activity.windowTitle}');
        if (activity.capturedUrl != null) {
          buffer.write(' (${activity.capturedUrl})');
        }
        if (activity.capturedClipboard != null) {
          buffer.write(' [clipboard: ${activity.capturedClipboard}]');
        }
        buffer.writeln();
      }
    }

    if (investigationContext != null) {
      buffer
        ..writeln()
        ..writeln('--- Agentic memory investigation ---')
        ..writeln(investigationContext);
    }

    return buffer.toString();
  }

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _describeRange(DateRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (range.start == today) return 'today';
    if (range.start == yesterday && range.end == today) return 'yesterday';
    return '${_date(range.start)} to ${_date(range.end)}';
  }

  Stream<String> reply({
    required LlmProvider provider,
    required List<LlmMessage> history,
    required String userMessage,
    bool deepStudy = false,
  }) async* {
    final activityRange = parseTemporalRange(userMessage);
    final activities = await retrieveActivity(activityRange);
    final memoryAgent = agent;
    final List<Snippet> contextSnippets;
    final List<ActivitySummary> summaries;
    final List<MemoryEpisode> episodes;
    String? investigationContext;
    if (memoryAgent == null) {
      contextSnippets = await retrieveContext(userMessage);
      summaries = await retrieveRecentSummaries();
      final memoryMatches = await retrieveMemory(userMessage);
      episodes = memoryMatches.matches.map((match) => match.episode).toList();
      final memorySearchError = memoryMatches.semanticError;
      if (memorySearchError != null) {
        onSemanticSearchError?.call(memorySearchError);
      }
    } else {
      contextSnippets = const [];
      summaries = const [];
      episodes = const [];
      if (deepStudy) {
        investigationContext =
            (await memoryAgent.deepStudy(userMessage)).markdown;
      } else {
        investigationContext =
            (await memoryAgent.investigate(userMessage)).toPrompt();
      }
    }
    final recentHistory = history.length > maxHistoryMessages
        ? history.sublist(history.length - maxHistoryMessages)
        : history;
    final requestMessages = [
      LlmMessage(
        role: LlmRole.system,
        content: buildSystemPrompt(
          contextSnippets,
          activities,
          summaries,
          activityRange,
          episodes,
          investigationContext,
        ),
      ),
      ...recentHistory,
      LlmMessage(role: LlmRole.user, content: userMessage),
    ];
    yield* provider.chat(requestMessages);
  }
}
