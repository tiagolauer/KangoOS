import 'package:drift/drift.dart' show Value;

import '../activity/activity_span.dart';
import '../database/database.dart';
import '../database/tables/activity_summaries_table.dart';
import '../llm/llm_provider.dart';
import '../llm/llm_stream.dart';

enum SummaryError { noActivity, llmFailed, cancelled }

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

const defaultMaxPromptActivities = 200;

class ActivitySummarizer {
  ActivitySummarizer({
    required this.database,
    this.maxPromptActivities = defaultMaxPromptActivities,
  });

  final KangoosDatabase database;
  final int maxPromptActivities;

  Future<SummaryResult> summarize({
    required LlmProvider provider,
    required SummaryKind kind,
    required DateTime start,
    required DateTime end,
    CancelToken? cancelToken,
  }) async {
    final activities = await database.activitiesBetween(start, end);
    if (activities.isEmpty) {
      return const SummaryFailure(SummaryError.noActivity);
    }

    final prompt = _buildPrompt(activities, end);
    final String content;
    try {
      content = await collectLlmReply(
        provider.chat([LlmMessage(role: LlmRole.user, content: prompt)]),
        cancelToken: cancelToken,
      );
    } catch (_) {
      return const SummaryFailure(SummaryError.llmFailed);
    }
    if (cancelToken?.isCancelled ?? false) {
      return const SummaryFailure(SummaryError.cancelled);
    }

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

  String _buildPrompt(List<Activity> activities, DateTime end) {
    final buffer = StringBuffer(
      'Summarize the developer activity below in 2-4 concise sentences, grouped by '
      "what was worked on. Only use what's listed — do not invent details. "
      'Each line ends with how long that window stayed in focus.',
    );

    final spans = activitySpans(activities, until: end);
    final dropped = spans.length - maxPromptActivities;
    final shown = dropped > 0 ? spans.sublist(spans.length - maxPromptActivities) : spans;
    if (dropped > 0) {
      buffer.writeln();
      buffer.write(
          '($dropped earlier entries omitted; the most recent ${shown.length} follow.)');
    }

    for (final span in shown) {
      buffer.writeln();
      buffer.write('- ${span.activity.capturedAt.toLocal()} · '
          '${span.activity.appName} · ${span.activity.windowTitle} · '
          '${formatActivityDuration(span.duration)}');
    }
    return buffer.toString();
  }
}
