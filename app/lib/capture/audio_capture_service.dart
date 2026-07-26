import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:kangoos_core/kangoos_core.dart';
import 'package:path/path.dart' as p;

import 'capture_settings_repository.dart';
import 'whisper_model_repository.dart';
import 'window_capture_service.dart';

const audioClipSeconds = 30;
const audioCaptureTimeout = Duration(seconds: 60);
const audioTranscribeTimeout = Duration(minutes: 5);

enum AudioCaptureOutcome { captured, silent, disabled, unavailable, failed }

class AudioCaptureService {
  AudioCaptureService({
    required this.database,
    required this.settingsRepository,
    required this.modelRepository,
    this.interval = const Duration(minutes: 10),
    this.clipSeconds = audioClipSeconds,
    WindowSnapshot? Function()? readWindow,
    Future<String?> Function(String modelPath, int seconds)? recordAndTranscribe,
  })  : readWindow = readWindow ?? WindowCaptureService.defaultWindowReader(),
        recordAndTranscribe = recordAndTranscribe ?? _viaHelpers;

  final KangoosDatabase database;
  final CaptureSettingsRepository settingsRepository;
  final WhisperModelRepository modelRepository;
  final Duration interval;
  final int clipSeconds;
  final WindowSnapshot? Function() readWindow;
  final Future<String?> Function(String modelPath, int seconds)
      recordAndTranscribe;

  Timer? _timer;
  var _running = false;

  static bool get isSupported => Platform.isWindows;

  void start() {
    if (!isSupported || _timer != null) return;
    _timer = Timer.periodic(interval, (_) => tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<AudioCaptureOutcome> tick() async {
    if (_running) return AudioCaptureOutcome.disabled;
    final settings = await settingsRepository.load();
    if (settings.paused || !settings.captureAudio) {
      return AudioCaptureOutcome.disabled;
    }
    if (!await modelRepository.isDownloaded()) {
      return AudioCaptureOutcome.unavailable;
    }

    _running = true;
    try {
      final transcript =
          await recordAndTranscribe(await modelRepository.modelPath(), clipSeconds);
      if (transcript == null) return AudioCaptureOutcome.silent;

      final snapshot = readWindow();
      final appName = snapshot?.appName ?? 'microphone';
      if (settings.excludedApps.contains(appName)) {
        return AudioCaptureOutcome.disabled;
      }

      await database.logActivity(ActivitiesCompanion.insert(
        appName: appName,
        windowTitle: snapshot?.windowTitle ?? 'Audio transcript',
        capturedAudioText: Value(transcript),
      ));
      return AudioCaptureOutcome.captured;
    } catch (_) {
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
      if (recorded.exitCode != 0) return null;

      final transcribed = await Process.run(
        transcriber,
        [modelPath, clip.path],
        stdoutEncoding: utf8,
      ).timeout(audioTranscribeTimeout);
      if (transcribed.exitCode != 0) return null;

      final text = (transcribed.stdout as String).trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
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
