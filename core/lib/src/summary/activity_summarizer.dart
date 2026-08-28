import '../activity/activity_span.dart';
import '../database/database.dart';
import '../database/tables/activity_summaries_table.dart';
import '../llm/llm_provider.dart';
import '../llm/llm_stream.dart';
import '../memory/activity_repository.dart';
import '../memory/summary_repository.dart';

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
    required this.activities,
    required this.summaries,
    this.maxPromptActivities = defaultMaxPromptActivities,
  });

  final ActivityRepository activities;
  final SummaryRepository summaries;
  final int maxPromptActivities;

  Future<SummaryResult> summarize({
    required LlmProvider provider,
    required SummaryKind kind,
    required DateTime start,
    required DateTime end,
    CancelToken? cancelToken,
  }) async {
    final captured = await activities.between(start, end);
    if (captured.isEmpty) {
      return const SummaryFailure(SummaryError.noActivity);
    }

    final prompt = _buildPrompt(captured, end);
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
    final id = await summaries.create(NewActivitySummary(
      kind: kind,
      periodStart: start,
      periodEnd: end,
      content: content,
      createdAt: createdAt,
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
      'Responda sempre em português do Brasil (PT-BR). Resuma a atividade de '
      'desenvolvimento abaixo em 2 a 4 frases concisas, agrupadas pelo que foi '
      'feito. Use somente o que está listado e não invente detalhes. Cada linha '
      'termina com o tempo em que a janela ficou em foco.',
    );

    final spans = activitySpans(activities, until: end);
    final dropped = spans.length - maxPromptActivities;
    final shown =
        dropped > 0 ? spans.sublist(spans.length - maxPromptActivities) : spans;
    if (dropped > 0) {
      buffer.writeln();
      buffer.write(
          '($dropped registros anteriores omitidos; os ${shown.length} mais recentes aparecem abaixo.)');
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
