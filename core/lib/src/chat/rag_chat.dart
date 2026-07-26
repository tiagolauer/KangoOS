import '../database/database.dart';
import '../llm/llm_provider.dart';
import '../search/semantic_search.dart';
import 'temporal_query.dart';

class RagChat {
  RagChat({
    required this.database,
    required this.semanticSearch,
    this.maxContextSnippets = 5,
    this.maxContextActivities = 30,
    this.maxContextSummaries = 5,
  });

  final KangoosDatabase database;
  final SemanticSearch semanticSearch;
  final int maxContextSnippets;
  final int maxContextActivities;
  final int maxContextSummaries;

  static const _queryBoundarySlack = Duration(seconds: 1);

  Future<List<Snippet>> retrieveContext(String query) async {
    try {
      final matches = await semanticSearch.search(query, limit: maxContextSnippets);
      if (matches.isNotEmpty) return matches.map((match) => match.snippet).toList();
    } catch (_) {}
    final matches = await database.searchByKeyword(query);
    return matches.take(maxContextSnippets).toList();
  }

  Future<List<Activity>> retrieveActivity(DateRange range) async {
    final activities = await database.activitiesBetween(
        range.start, range.end.add(_queryBoundarySlack));
    final recent = activities.length > maxContextActivities
        ? activities.sublist(activities.length - maxContextActivities)
        : activities;
    return recent.reversed.toList();
  }

  Future<List<ActivitySummary>> retrieveRecentSummaries() =>
      database.recentSummaries(limit: maxContextSummaries);

  String buildSystemPrompt(
    List<Snippet> snippets,
    List<Activity> activities,
    List<ActivitySummary> summaries,
    DateRange activityRange,
  ) {
    final buffer = StringBuffer(
      'You are the KangoOS assistant. Answer using the snippets and captured '
      "activity below when relevant. If nothing is relevant, say so and "
      'answer generally.',
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
      buffer.writeln('--- Captured activity (${_describeRange(activityRange)}) ---');
      for (final activity in activities) {
        buffer.write('[${_time(activity.capturedAt)}] '
            '${activity.appName} — ${activity.windowTitle}');
        if (activity.capturedUrl != null) buffer.write(' (${activity.capturedUrl})');
        buffer.writeln();
      }
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
  }) async* {
    final snippets = await retrieveContext(userMessage);
    final activityRange = parseTemporalRange(userMessage);
    final activities = await retrieveActivity(activityRange);
    final summaries = await retrieveRecentSummaries();
    final requestMessages = [
      LlmMessage(
        role: LlmRole.system,
        content: buildSystemPrompt(snippets, activities, summaries, activityRange),
      ),
      ...history,
      LlmMessage(role: LlmRole.user, content: userMessage),
    ];
    yield* provider.chat(requestMessages);
  }
}
