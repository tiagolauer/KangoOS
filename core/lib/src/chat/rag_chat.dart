import '../database/database.dart';
import '../llm/llm_provider.dart';
import '../search/semantic_search.dart';

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

  Future<List<Activity>> retrieveTodayActivity() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final activities = await database.activitiesBetween(
        startOfDay, now.add(_queryBoundarySlack));
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
      buffer.writeln("--- Today's captured activity ---");
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

  Stream<String> reply({
    required LlmProvider provider,
    required List<LlmMessage> history,
    required String userMessage,
  }) async* {
    final snippets = await retrieveContext(userMessage);
    final activities = await retrieveTodayActivity();
    final summaries = await retrieveRecentSummaries();
    final requestMessages = [
      LlmMessage(
        role: LlmRole.system,
        content: buildSystemPrompt(snippets, activities, summaries),
      ),
      ...history,
      LlmMessage(role: LlmRole.user, content: userMessage),
    ];
    yield* provider.chat(requestMessages);
  }
}
