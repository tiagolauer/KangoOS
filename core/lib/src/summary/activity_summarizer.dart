import 'package:drift/drift.dart' show Value;

import '../database/database.dart';
import '../database/tables/activity_summaries_table.dart';
import '../llm/llm_provider.dart';

enum SummaryError { noActivity, llmFailed }

sealed class SummaryResult {
  const SummaryResult();
}

class SummarySuccess extends SummaryResult {
  const SummarySuccess(this.summary);

  final ActivitySummary summary;
}

class SummaryFailure extends SummaryResult {
  const SummaryFailure(this.error);

  final SummaryError error;
}

class ActivitySummarizer {
  ActivitySummarizer({required this.database});

  final KangoosDatabase database;

  Future<SummaryResult> summarize({
    required LlmProvider provider,
    required SummaryKind kind,
    required DateTime start,
    required DateTime end,
  }) async {
    final activities = await database.activitiesBetween(start, end);
    if (activities.isEmpty) {
      return const SummaryFailure(SummaryError.noActivity);
    }

    final prompt = _buildPrompt(activities);
    final buffer = StringBuffer();
    try {
      await for (final chunk
          in provider.chat([LlmMessage(role: LlmRole.user, content: prompt)])) {
        buffer.write(chunk);
      }
    } catch (_) {
      return const SummaryFailure(SummaryError.llmFailed);
    }

    final content = buffer.toString();
    final createdAt = DateTime.now();
    final id =
        await database.insertActivitySummary(ActivitySummariesCompanion.insert(
      kind: kind,
      periodStart: start,
      periodEnd: end,
      content: content,
      createdAt: Value(createdAt),
    ));

    return SummarySuccess(ActivitySummary(
      id: id,
      kind: kind,
      periodStart: start,
      periodEnd: end,
      content: content,
      createdAt: createdAt,
    ));
  }

  String _buildPrompt(List<Activity> activities) {
    final buffer = StringBuffer(
      'Summarize the developer activity below in 2-4 concise sentences, grouped by '
      "what was worked on. Only use what's listed — do not invent details.",
    );
    for (final activity in activities) {
      buffer.writeln();
      buffer.write(
          '- ${activity.capturedAt.toLocal()} · ${activity.appName} · ${activity.windowTitle}');
    }
    return buffer.toString();
  }
}
