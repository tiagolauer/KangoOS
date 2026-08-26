import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:path/path.dart' as p;

import 'capture_settings_repository.dart';
import 'capture_environment.dart';
import 'capture_source_registry.dart';
import 'capture_status.dart';
import 'whisper_model_repository.dart';
import 'window_capture_service.dart';
import '../runtime/runtime_service.dart';

const audioClipSeconds = 10;
const audioCaptureInterval = Duration(seconds: 10);
const audioCaptureTimeout = Duration(seconds: 60);
const audioTranscribeTimeout = Duration(minutes: 5);
const audioSessionInactivityGap = Duration(minutes: 15);
const maxAudioSessionSummaryLength = 4000;
const audioCaptureSilentExitCode = 4;

enum AudioCaptureOutcome { captured, silent, disabled, unavailable, failed }

class AudioTranscriptChunk {
  const AudioTranscriptChunk({
    required this.startedAt,
    required this.endedAt,
    required this.text,
    required this.appName,
    required this.windowTitle,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final String text;
  final String appName;
  final String windowTitle;
}

class AudioSessionIntelligence {
  AudioSessionIntelligence({
    required this.memory,
    this.inactivityGap = audioSessionInactivityGap,
  });

  final MemoryService memory;
  final Duration inactivityGap;
  final _chunks = <AudioTranscriptChunk>[];

  Future<ActivitySummary?> add(AudioTranscriptChunk chunk) async {
    ActivitySummary? formed;
    if (_chunks.isNotEmpty &&
        chunk.startedAt.difference(_chunks.last.endedAt) > inactivityGap) {
      formed = await flush();
    }
    _chunks.add(chunk);
    _chunks.sort((left, right) => left.startedAt.compareTo(right.startedAt));
    return formed;
  }

  Future<ActivitySummary?> closeInactive(DateTime now) async {
    if (_chunks.isEmpty ||
        now.difference(_chunks.last.endedAt) < inactivityGap) {
      return null;
    }
    return flush();
  }

  Future<ActivitySummary?> flush() async {
    if (_chunks.isEmpty) return null;
    final chunks = List<AudioTranscriptChunk>.of(_chunks);
    _chunks.clear();
    final applications = chunks.map((chunk) => chunk.appName).toSet().toList();
    final meeting = applications.any(_isMeetingApp);
    final transcript = chunks.map((chunk) => chunk.text.trim()).join('\n');
    final label = meeting ? 'Reunião' : 'Áudio';
    final content = 'Sessão de $label em ${applications.join(', ')} '
        '(${chunks.length} trecho${chunks.length == 1 ? '' : 's'} de transcrição):\n'
        '$transcript';
    return memory.remember(
      content.length <= maxAudioSessionSummaryLength
          ? content
          : content.substring(0, maxAudioSessionSummaryLength),
      at: chunks.first.startedAt,
      endAt: chunks.last.endedAt,
      kind: SummaryKind.session,
    );
  }

  bool _isMeetingApp(String appName) {
    final normalized = appName.toLowerCase();
    return const [
      'teams',
      'zoom',
      'meet',
      'slack',
      'discord',
    ].any(normalized.contains);
  }
}

class AudioCaptureService implements RuntimeService {
  AudioCaptureService({
    required this.memory,
    required this.settingsRepository,
    required this.modelRepository,
    CaptureSourceRegistry? sourceRegistry,
    this.captureStatus,
    this.interval = audioCaptureInterval,
    this.clipSeconds = audioClipSeconds,
    WindowSnapshot? Function()? readWindow,
    DateTime Function()? now,
    AudioSessionIntelligence? sessionIntelligence,
    CaptureEnvironmentReader? readEnvironment,
    this.onError,
    Future<String?> Function(String modelPath, int seconds)?
        recordAndTranscribe,
  })  : sourceRegistry = sourceRegistry ?? CaptureSourceRegistry(),
        readWindow = readWindow ?? WindowCaptureService.defaultWindowReader(),
        now = now ?? DateTime.now,
        readEnvironment = readEnvironment ?? CaptureEnvironment.read,
        sessionIntelligence =
            sessionIntelligence ?? AudioSessionIntelligence(memory: memory),
        recordAndTranscribe = recordAndTranscribe ?? _viaHelpers;

  final MemoryService memory;
  final CaptureSettingsRepository settingsRepository;
  final WhisperModelRepository modelRepository;
  final CaptureSourceRegistry sourceRegistry;
  final CaptureStatusController? captureStatus;
  final Duration interval;
  final int clipSeconds;
  final WindowSnapshot? Function() readWindow;
  final DateTime Function() now;
  final CaptureEnvironmentReader readEnvironment;
  final AudioSessionIntelligence sessionIntelligence;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final Future<String?> Function(String modelPath, int seconds)
      recordAndTranscribe;

  Timer? _timer;
  var _activeCaptures = 0;
  var _captureEpoch = 0;
  Object? lastError;
  StackTrace? lastStackTrace;

  static bool get isSupported => Platform.isWindows;

  @override
  Future<void> start() async {
    if (!isSupported || _timer != null) return;
    unawaited(tickSafely());
    _timer = Timer.periodic(interval, (_) => unawaited(tickSafely()));
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _captureEpoch++;
    captureStatus?.setMicrophoneActive(false);
    await sessionIntelligence.flush();
  }

  Future<AudioCaptureOutcome> tickSafely() async {
    try {
      return await tick();
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
      return AudioCaptureOutcome.failed;
    }
  }

  Future<AudioCaptureOutcome> tick() async {
    final captureEpoch = _captureEpoch;
    final settings = await settingsRepository.load();
    final environment = await readEnvironment();
    captureStatus?.setEnvironment(environment);
    if (settings.paused || !settings.captureAudio || environment.locked) {
      await sessionIntelligence.closeInactive(now());
      return AudioCaptureOutcome.disabled;
    }
    final snapshot = readWindow();
    if (snapshot == null) return AudioCaptureOutcome.unavailable;
    final source = await sourceRegistry.observe(snapshot);
    if (!source.canCapture ||
        WindowCaptureService.isExcluded(
          snapshot.appName,
          settings.excludedApps,
          snapshot.appId,
        )) {
      return AudioCaptureOutcome.disabled;
    }
    if (!await modelRepository.isDownloaded()) {
      return AudioCaptureOutcome.unavailable;
    }

    final startedAt = now();
    _activeCaptures++;
    captureStatus?.setMicrophoneActive(true);
    try {
      final transcript = await recordAndTranscribe(
        await modelRepository.modelPath(),
        clipSeconds,
      );
      if (transcript == null) {
        await sessionIntelligence.closeInactive(now());
        return AudioCaptureOutcome.silent;
      }

      final finalSettings = await settingsRepository.load();
      final finalEnvironment = await readEnvironment();
      captureStatus?.setEnvironment(finalEnvironment);
      final finalSnapshot = readWindow();
      if (finalSettings.paused ||
          !finalSettings.captureAudio ||
          captureEpoch != _captureEpoch ||
          finalEnvironment.locked ||
          finalSnapshot == null ||
          !snapshot.isSameTarget(finalSnapshot)) {
        return AudioCaptureOutcome.disabled;
      }
      final finalSource = await sourceRegistry.observe(finalSnapshot);
      if (!finalSource.canCapture ||
          WindowCaptureService.isExcluded(
            finalSnapshot.appName,
            finalSettings.excludedApps,
            finalSnapshot.appId,
          )) {
        return AudioCaptureOutcome.disabled;
      }

      final endedAt = startedAt.add(Duration(seconds: clipSeconds));
      await memory.record(
        NewActivity(
          sourceId: snapshot.appId,
          appName: snapshot.appName,
          windowTitle: snapshot.windowTitle,
          capturedAudioText: transcript,
          capturedAt: endedAt,
        ),
      );
      await sessionIntelligence.add(
        AudioTranscriptChunk(
          startedAt: startedAt,
          endedAt: endedAt,
          text: transcript,
          appName: snapshot.appName,
          windowTitle: snapshot.windowTitle,
        ),
      );
      await sourceRegistry.markCaptured(source.id, endedAt, const {
        CaptureModality.audio,
      });
      return AudioCaptureOutcome.captured;
    } catch (error, stackTrace) {
      _reportError(error, stackTrace);
      return AudioCaptureOutcome.failed;
    } finally {
      _activeCaptures--;
      if (_activeCaptures == 0) captureStatus?.setMicrophoneActive(false);
    }
  }

  void _reportError(Object error, StackTrace stackTrace) {
    lastError = error;
    lastStackTrace = stackTrace;
    onError?.call(error, stackTrace);
  }

  static Future<String?> _viaHelpers(String modelPath, int seconds) async {
    final recorder = _helperPath('audio_capture.exe');
    final transcriber = _helperPath('whisper_transcribe.exe');
    if (recorder == null || transcriber == null) return null;

    final clip = File(
      p.join(
        Directory.systemTemp.path,
        'kangoos_audio_${DateTime.now().microsecondsSinceEpoch}.wav',
      ),
    );

    try {
      final recorded = await Process.run(recorder, [
        clip.path,
        '$seconds',
      ]).timeout(audioCaptureTimeout);
      if (recorded.exitCode == audioCaptureSilentExitCode) return null;
      if (recorded.exitCode != 0) {
        throw ProcessException(
          recorder,
          [clip.path, '$seconds'],
          '${recorded.stderr}',
          recorded.exitCode,
        );
      }

      final transcribed = await Process.run(
              transcriber,
              [
                modelPath,
                clip.path,
              ],
              stdoutEncoding: utf8)
          .timeout(audioTranscribeTimeout);
      if (transcribed.exitCode != 0) {
        throw ProcessException(
          transcriber,
          [modelPath, clip.path],
          '${transcribed.stderr}',
          transcribed.exitCode,
        );
      }

      final text = (transcribed.stdout as String).trim();
      return text.isEmpty ? null : text;
    } finally {
      if (clip.existsSync()) clip.deleteSync();
    }
  }

  static String? _helperPath(String executable) {
    if (!Platform.isWindows) return null;
    final helper = p.join(p.dirname(Platform.resolvedExecutable), executable);
    return File(helper).existsSync() ? helper : null;
  }
}
