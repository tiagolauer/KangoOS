import 'dart:async';

import 'package:kangoos_core/kangoos_core.dart';

import '../settings_repository.dart';
import 'summary_watermark_repository.dart';

const maxSummaryCatchUp = Duration(hours: 2);

class ActivitySummaryService {
  ActivitySummaryService({
    required this.database,
    required this.settingsRepository,
    ActivitySummarizer? summarizer,
    SummaryWatermarkRepository? watermarkRepository,
    this.interval = const Duration(minutes: 20),
    DateTime Function()? now,
    LlmProvider Function(LlmSettings settings)? providerBuilder,
  })  : summarizer = summarizer ?? ActivitySummarizer(database: database),
        watermarkRepository =
            watermarkRepository ?? SummaryWatermarkRepository(),
        now = now ?? DateTime.now,
        providerBuilder = providerBuilder ?? ((s) => s.buildProvider());

  final KangoosDatabase database;
  final SettingsRepository settingsRepository;
  final ActivitySummarizer summarizer;
  final SummaryWatermarkRepository watermarkRepository;
  final Duration interval;
  final DateTime Function() now;

  /// Overridable for tests; defaults to [LlmSettings.buildProvider].
  final LlmProvider Function(LlmSettings settings) providerBuilder;

  Timer? _timer;
  DateTime? _lastPeriodEnd;
  bool _ticking = false;

  Future<void> start() async {
    if (_timer != null) return;
    final startedAt = now();
    _lastPeriodEnd = startedAt;
    _timer = Timer.periodic(interval, (_) => tickSafely());

    final stored = await watermarkRepository.load();
    if (stored == null) {
      await watermarkRepository.save(startedAt);
      return;
    }
    _lastPeriodEnd = _notOlderThanCatchUp(stored, startedAt);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<SummaryResult?> tickSafely() async {
    if (_ticking) return null;
    _ticking = true;
    try {
      return await tick();
    } finally {
      _ticking = false;
    }
  }

  DateTime _notOlderThanCatchUp(DateTime start, DateTime reference) {
    final oldestAllowed = reference.subtract(maxSummaryCatchUp);
    return start.isBefore(oldestAllowed) ? oldestAllowed : start;
  }

  Future<SummaryResult?> tick() async {
    final periodEnd = now();
    final periodStart =
        _notOlderThanCatchUp(_lastPeriodEnd ?? periodEnd, periodEnd);

    final activities = await database.activitiesBetween(periodStart, periodEnd);
    if (activities.isEmpty) {
      await _advanceTo(periodEnd);
      return null;
    }

    final settings = await settingsRepository.load();
    final unconfigured = settings.model.isEmpty ||
        (settings.provider != LlmProviderKind.ollama &&
            settings.apiKey.isEmpty);
    if (unconfigured) {
      await _advanceTo(periodEnd);
      return null;
    }

    final result = await summarizer.summarize(
      provider: providerBuilder(settings),
      kind: SummaryKind.periodic,
      start: periodStart,
      end: periodEnd,
    );
    if (result is SummaryFailure && result.error == SummaryError.llmFailed) {
      return result;
    }
    await _advanceTo(periodEnd);
    return result;
  }

  Future<void> _advanceTo(DateTime periodEnd) async {
    _lastPeriodEnd = periodEnd;
    await watermarkRepository.save(periodEnd);
  }
}
