import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:path/path.dart' as p;

import 'capture_settings_repository.dart';
import 'whisper_model_repository.dart';
import 'window_capture_service.dart';
import '../runtime/runtime_service.dart';

const audioClipSeconds = 30;
const audioCaptureTimeout = Duration(seconds: 60);
const audioTranscribeTimeout = Duration(minutes: 5);
const audioSessionInactivityGap = Duration(minutes: 15);
const maxAudioSessionSummaryLength = 4000;

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
    return const ['teams', 'zoom', 'meet', 'slack', 'discord']
        .any(normalized.contains);
  }
}

class AudioCaptureService implements RuntimeService {
  AudioCaptureService({
    required this.memory,
    required this.settingsRepository,
    required this.modelRepository,
    this.interval = const Duration(minutes: 10),
    this.clipSeconds = audioClipSeconds,
    WindowSnapshot? Function()? readWindow,
    DateTime Function()? now,
    AudioSessionIntelligence? sessionIntelligence,
    this.onError,
    Future<String?> Function(String modelPath, int seconds)?
        recordAndTranscribe,
  })  : readWindow = readWindow ?? WindowCaptureService.defaultWindowReader(),
        now = now ?? DateTime.now,
        sessionIntelligence =
            sessionIntelligence ?? AudioSessionIntelligence(memory: memory),
        recordAndTranscribe = recordAndTranscribe ?? _viaHelpers;

  final MemoryService memory;
  final CaptureSettingsRepository settingsRepository;
  final WhisperModelRepository modelRepository;
  final Duration interval;
  final int clipSeconds;
  final WindowSnapshot? Function() readWindow;
  final DateTime Function() now;
  final AudioSessionIntelligence sessionIntelligence;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final Future<String?> Function(String modelPath, int seconds)
      recordAndTranscribe;

  Timer? _timer;
  var _running = false;
  Object? lastError;
  StackTrace? lastStackTrace;

  static bool get isSupported => Platform.isWindows;

  @override
  Future<void> start() async {
    if (!isSupported || _timer != null) return;
    _timer = Timer.periodic(interval, (_) => tick());
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await sessionIntelligence.flush();
  }

  Future<AudioCaptureOutcome> tick() async {
    if (_running) return AudioCaptureOutcome.disabled;
    final settings = await settingsRepository.load();
    if (settings.paused || !settings.captureAudio) {
      await sessionIntelligence.closeInactive(now());
      return AudioCaptureOutcome.disabled;
    }
    if (!await modelRepository.isDownloaded()) {
      return AudioCaptureOutcome.unavailable;
    }

    _running = true;
    try {
      final transcript = await recordAndTranscribe(
          await modelRepository.modelPath(), clipSeconds);
      if (transcript == null) {
        await sessionIntelligence.closeInactive(now());
        return AudioCaptureOutcome.silent;
      }

      final snapshot = readWindow();
      final appName = snapshot?.appName ?? 'microfone';
      if (settings.excludedApps.contains(appName)) {
        return AudioCaptureOutcome.disabled;
      }

      final endedAt = now();
      final startedAt = endedAt.subtract(Duration(seconds: clipSeconds));
      await memory.record(NewActivity(
        appName: appName,
        windowTitle: snapshot?.windowTitle ?? 'Transcrição de áudio',
        capturedAudioText: transcript,
        capturedAt: endedAt,
      ));
      await sessionIntelligence.add(AudioTranscriptChunk(
        startedAt: startedAt,
        endedAt: endedAt,
        text: transcript,
        appName: appName,
        windowTitle: snapshot?.windowTitle ?? 'Transcrição de áudio',
      ));
      return AudioCaptureOutcome.captured;
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
      onError?.call(error, stackTrace);
      return AudioCaptureOutcome.failed;
    } finally {
      _running = false;
    }
  }

  static Future<String?> _viaHelpers(String modelPath, int seconds) async {
    final recorder = _helperPath('audio_capture.exe');
    final transcriber = _helperPath('whisper_transcribe.exe');
    if (recorder == null || transcriber == null) return null;

    final clip = File(p.join(
      Directory.systemTemp.path,
      'kangoos_audio_${DateTime.now().microsecondsSinceEpoch}.wav',
    ));

    try {
      final recorded = await Process.run(
        recorder,
        [clip.path, '$seconds'],
      ).timeout(audioCaptureTimeout);
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
        [modelPath, clip.path],
        stdoutEncoding: utf8,
      ).timeout(audioTranscribeTimeout);
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
