import 'dart:async';

import 'package:kangoos_core/kangoos_core.dart';

import '../settings_repository.dart';

class ActivitySummaryService {
  ActivitySummaryService({
    required this.database,
    required this.settingsRepository,
    ActivitySummarizer? summarizer,
    this.interval = const Duration(minutes: 20),
    DateTime Function()? now,
    LlmProvider Function(LlmSettings settings)? providerBuilder,
  })  : summarizer = summarizer ?? ActivitySummarizer(database: database),
        now = now ?? DateTime.now,
        providerBuilder = providerBuilder ?? ((s) => s.buildProvider());

  final KangoosDatabase database;
  final SettingsRepository settingsRepository;
  final ActivitySummarizer summarizer;
  final Duration interval;
  final DateTime Function() now;

  /// Overridable for tests; defaults to [LlmSettings.buildProvider].
  final LlmProvider Function(LlmSettings settings) providerBuilder;

  Timer? _timer;
  DateTime? _lastPeriodEnd;

  void start() {
    if (_timer != null) return;
    _lastPeriodEnd = now();
    _timer = Timer.periodic(interval, (_) => tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<SummaryResult?> tick() async {
    final periodStart = _lastPeriodEnd ?? now();
    final periodEnd = now();

    final activities = await database.activitiesBetween(periodStart, periodEnd);
    if (activities.isEmpty) {
      _lastPeriodEnd = periodEnd;
      return null;
    }

    final settings = await settingsRepository.load();
    if (settings.model.isEmpty) return null;
    if (settings.provider != LlmProviderKind.ollama &&
        settings.apiKey.isEmpty) {
      return null;
    }

    final result = await summarizer.summarize(
      provider: providerBuilder(settings),
      kind: SummaryKind.periodic,
      start: periodStart,
      end: periodEnd,
    );
    _lastPeriodEnd = periodEnd;
    return result;
  }
}
