import 'dart:async';
import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';

import '../settings_repository.dart';
import 'capture_settings_repository.dart';
import 'summary_watermark_repository.dart';
import '../runtime/runtime_service.dart';

const maxSummaryCatchUp = Duration(hours: 2);

class ActivitySummaryService implements RuntimeService {
  ActivitySummaryService({
    required this.memory,
    required this.settingsRepository,
    required this.captureSettingsRepository,
    ActivitySummarizer? summarizer,
    SummaryWatermarkRepository? watermarkRepository,
    this.interval = const Duration(minutes: 20),
    DateTime Function()? now,
    LlmProvider Function(LlmSettings settings)? providerBuilder,
    this.memoryFormation,
    void Function(MemoryFormationReport report)? onMemoryFormation,
  })  : summarizer = summarizer ??
            ActivitySummarizer(
              activities: memory.activities,
              summaries: memory.summaries,
            ),
        watermarkRepository =
            watermarkRepository ?? SummaryWatermarkRepository(),
        now = now ?? DateTime.now,
        providerBuilder = providerBuilder ?? ((s) => s.buildProvider()),
        onMemoryFormation = onMemoryFormation ?? _reportMemoryFormation;

  final MemoryService memory;
  final SettingsRepository settingsRepository;
  final CaptureSettingsRepository captureSettingsRepository;
  final ActivitySummarizer summarizer;
  final SummaryWatermarkRepository watermarkRepository;
  final Duration interval;
  final DateTime Function() now;

  /// Overridable for tests; defaults to [LlmSettings.buildProvider].
  final LlmProvider Function(LlmSettings settings) providerBuilder;
  final MemoryFormationService? memoryFormation;
  final void Function(MemoryFormationReport report) onMemoryFormation;

  Timer? _timer;
  DateTime? _lastPeriodEnd;
  bool _ticking = false;

  @override
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

  @override
  Future<void> stop() async {
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

    final activities = await memory.between(periodStart, periodEnd);
    if (activities.isEmpty) {
      await _advanceTo(periodEnd);
      return null;
    }

    final settings = await settingsRepository.load();
    final captureSettings = await captureSettingsRepository.load();
    final formation = memoryFormation;
    if (formation != null) {
      onMemoryFormation(await formation.formBetween(
        periodStart,
        periodEnd,
        indexEmbeddings:
            settings.isLocalEndpoint || captureSettings.allowRemoteSummaries,
      ));
    }
    final unconfigured = settings.model.isEmpty ||
        (settings.requiresApiKey && settings.apiKey.isEmpty);
    if (unconfigured) {
      await _advanceTo(periodEnd);
      return null;
    }
    if (!isLocalAutomaticSummary(settings) &&
        !captureSettings.allowRemoteSummaries) {
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

  static void _reportMemoryFormation(MemoryFormationReport report) {
    if (report.indexingFailures.isEmpty) return;
    stderr.writeln(
      'Memory episode indexing failed for IDs: '
      '${report.indexingFailures.keys.join(', ')}',
    );
  }
}

bool isLocalAutomaticSummary(LlmSettings settings) {
  return settings.isLocalEndpoint;
}

bool isLocalOllamaEndpoint(LlmSettings settings) {
  final uri = Uri.tryParse(settings.ollamaBaseUrl);
  final host = uri?.host.toLowerCase() ?? '';
  return host == 'localhost' ||
      host == '::1' ||
      host == '0:0:0:0:0:0:0:1' ||
      host.startsWith('127.');
}
