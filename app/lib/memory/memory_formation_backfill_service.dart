import 'dart:async';
import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../capture/capture_settings_repository.dart';
import '../runtime/runtime_service.dart';
import '../settings_repository.dart';

const defaultFormationBackfillBatch = Duration(hours: 6);
const defaultFormationBackfillInterval = Duration(minutes: 1);

class MemoryFormationBackfillService implements RuntimeService {
  MemoryFormationBackfillService({
    required this.formation,
    required this.settingsRepository,
    required this.captureSettingsRepository,
    this.queryEngine,
    this.batchSpan = defaultFormationBackfillBatch,
    this.interval = defaultFormationBackfillInterval,
    DateTime Function()? now,
    LlmProvider Function(LlmSettings settings)? providerBuilder,
    void Function(Object error)? onError,
  }) : now = now ?? DateTime.now,
       providerBuilder =
           providerBuilder ?? ((settings) => settings.buildProvider()),
       onError = onError ?? _reportError;

  final MemoryFormationService formation;
  final SettingsRepository settingsRepository;
  final CaptureSettingsRepository captureSettingsRepository;
  final MemoryQueryEngine? queryEngine;
  final Duration batchSpan;
  final Duration interval;
  final DateTime Function() now;
  final LlmProvider Function(LlmSettings settings) providerBuilder;
  final void Function(Object error) onError;

  Timer? _timer;
  Future<void>? _active;
  bool _running = false;

  String get _cursorKey =>
      'memory_formation_backfill_cursor_v$currentMemoryFormationVersion';
  String get _modelKey =>
      'memory_formation_backfill_model_v$currentMemoryFormationVersion';

  @override
  Future<void> start() async {
    if (_timer != null) return;
    _timer = Timer.periodic(interval, (_) => _run());
    _run();
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _active;
  }

  void _run() {
    if (_active != null) return;
    _active = _runSafely();
    unawaited(_active!.whenComplete(() => _active = null));
  }

  Future<void> _runSafely() async {
    try {
      await tick();
    } catch (error) {
      onError(error);
    }
  }

  Future<MemoryBackfillBatch?> tick() async {
    if (_running) return null;
    _running = true;
    try {
      final target = now();
      final captureSettings = await captureSettingsRepository.load();
      final settings = await settingsRepository.load();
      final configured =
          settings.model.isNotEmpty &&
          (!settings.requiresApiKey || settings.apiKey.isNotEmpty);
      final enrichmentAllowed =
          configured &&
          (settings.isLocalEndpoint || captureSettings.allowRemoteSummaries);
      final modelId =
          enrichmentAllowed ? settings.inferenceModelId : 'deterministic';
      final retentionStart = target.subtract(
        Duration(days: captureSettings.retentionDays),
      );
      final preferences = await SharedPreferences.getInstance();
      final storedModel = preferences.getString(_modelKey);
      DateTime cursor;
      if (storedModel != modelId) {
        cursor = retentionStart;
        await preferences.setString(_modelKey, modelId);
        await preferences.setString(
          _cursorKey,
          cursor.toUtc().toIso8601String(),
        );
      } else {
        cursor =
            DateTime.tryParse(
              preferences.getString(_cursorKey) ?? '',
            )?.toLocal() ??
            retentionStart;
        if (cursor.isBefore(retentionStart)) cursor = retentionStart;
      }
      final enricher =
          enrichmentAllowed
              ? MemoryEpisodeEnricher(
                provider: providerBuilder(settings),
                modelId: modelId,
              )
              : null;
      final embeddingAllowed =
          settings.isLocalEndpoint || captureSettings.allowRemoteSummaries;
      final batch = await formation.backfillBatch(
        start: retentionStart,
        end: target,
        cursor: cursor,
        batchSpan: batchSpan,
        indexEmbeddings: embeddingAllowed,
        enricher: enricher,
      );
      if (batch.report.enrichmentFailures.isEmpty) {
        await preferences.setString(
          _cursorKey,
          batch.cursor.toUtc().toIso8601String(),
        );
      }
      final engine = queryEngine;
      if (engine != null && embeddingAllowed) {
        try {
          final report = await engine.indexPending();
          for (final failure in report.failures.values) {
            onError(failure);
          }
        } catch (error) {
          onError(error);
        }
      }
      return batch;
    } finally {
      _running = false;
    }
  }

  static void _reportError(Object error) {
    stderr.writeln('Memory formation backfill failed: $error');
  }
}
