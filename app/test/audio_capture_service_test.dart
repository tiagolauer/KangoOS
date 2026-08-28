import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_app/capture/audio_capture_service.dart';
import 'package:kangoos_app/capture/capture_environment.dart';
import 'package:kangoos_app/capture/capture_settings_repository.dart';
import 'package:kangoos_app/capture/capture_source_registry.dart';
import 'package:kangoos_app/capture/whisper_model_repository.dart';
import 'package:kangoos_app/capture/window_capture_service.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_services.dart';

class _FakeModelRepository implements WhisperModelRepository {
  _FakeModelRepository({this.present = true});

  final bool present;

  @override
  Future<bool> isDownloaded() async => present;

  @override
  Future<String> modelPath() async => 'C:/fake/ggml-base.bin';

  @override
  Future<ModelDownloadResult> download({
    void Function(int received, int total)? onProgress,
  }) async =>
      const ModelDownloadSuccess('C:/fake/ggml-base.bin');

  @override
  Future<void> delete() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KangoosDatabase database;
  late TestServices services;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final sources = CaptureSourceRegistry();
    await sources.observe(
      const WindowSnapshot(appName: 'teams.exe', windowTitle: 'Standup'),
    );
    await sources.setEnabled('teams.exe', true);
    database = KangoosDatabase.memory();
    services = TestServices(database);
  });
  tearDown(() => database.close());

  Future<AudioCaptureService> build({
    required CaptureSettings settings,
    bool modelPresent = true,
    DateTime Function()? now,
    Future<String?> Function(String, int)? transcribe,
  }) async {
    final repository = CaptureSettingsRepository();
    await repository.save(settings);
    return AudioCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      modelRepository: _FakeModelRepository(present: modelPresent),
      readWindow: () => const WindowSnapshot(
        appName: 'teams.exe',
        windowTitle: 'Standup',
      ),
      now: now,
      readEnvironment: () async => const CaptureEnvironmentState(),
      recordAndTranscribe:
          transcribe ?? (_, __) async => 'discussed the roadmap',
    );
  }

  test('stores a transcript as an activity when enabled', () async {
    final service = await build(
      settings: const CaptureSettings(paused: false, captureAudio: true),
    );

    expect(await service.tick(), AudioCaptureOutcome.captured);

    final logged = await database.allActivities();
    expect(logged.single.capturedAudioText, 'discussed the roadmap');
    expect(logged.single.appName, 'teams.exe');
  });

  test('never records when the setting is off', () async {
    final service = await build(
      settings: const CaptureSettings(paused: false),
      transcribe: (_, __) async =>
          throw StateError('should not record when disabled'),
    );

    expect(await service.tick(), AudioCaptureOutcome.disabled);
    expect(await database.allActivities(), isEmpty);
  });

  test('never records while capture is paused', () async {
    final service = await build(
      settings: const CaptureSettings(paused: true, captureAudio: true),
      transcribe: (_, __) async =>
          throw StateError('should not record while paused'),
    );

    expect(await service.tick(), AudioCaptureOutcome.disabled);
  });

  test('does nothing when the speech model is missing', () async {
    final service = await build(
      settings: const CaptureSettings(paused: false, captureAudio: true),
      modelPresent: false,
      transcribe: (_, __) async =>
          throw StateError('should not record without a model'),
    );

    expect(await service.tick(), AudioCaptureOutcome.unavailable);
    expect(await database.allActivities(), isEmpty);
  });

  test('silence is not stored', () async {
    final service = await build(
      settings: const CaptureSettings(paused: false, captureAudio: true),
      transcribe: (_, __) async => null,
    );

    expect(await service.tick(), AudioCaptureOutcome.silent);
    expect(await database.allActivities(), isEmpty);
  });

  test('excluded apps are skipped', () async {
    final service = await build(
      settings: const CaptureSettings(
        paused: false,
        captureAudio: true,
        excludedApps: ['teams.exe'],
      ),
    );

    expect(await service.tick(), AudioCaptureOutcome.disabled);
    expect(await database.allActivities(), isEmpty);
  });

  test('transcripts are full-text searchable', () async {
    final service = await build(
      settings: const CaptureSettings(paused: false, captureAudio: true),
      transcribe: (_, __) async => 'we agreed to ship the migration on Friday',
    );
    await service.tick();

    final hits = await database.searchActivities('migration');
    expect(hits, hasLength(1));
    expect(hits.single.capturedAudioText, contains('migration'));
  });

  test('groups timestamped chunks into a meeting session memory', () async {
    var current = DateTime.utc(2026, 8, 25, 10);
    var transcript = 'first decision';
    final service = await build(
      settings: const CaptureSettings(paused: false, captureAudio: true),
      now: () => current,
      transcribe: (_, __) async => transcript,
    );
    await service.tick();
    current = current.add(const Duration(minutes: 10));
    transcript = 'second decision';
    await service.tick();
    current = current.add(const Duration(minutes: 10));
    transcript = 'third decision';
    await service.tick();

    await service.stop();

    final summaries = await database.recentSummaries();
    expect(summaries.single.kind, SummaryKind.session);
    expect(
      summaries.single.periodStart,
      DateTime.utc(2026, 8, 25, 10).toLocal(),
    );
    expect(
      summaries.single.periodEnd,
      DateTime.utc(2026, 8, 25, 10, 20, 10).toLocal(),
    );
    expect(summaries.single.content, contains('Sessão de Reunião'));
    expect(summaries.single.content, contains('first decision'));
    expect(summaries.single.content, contains('second decision'));
    expect(summaries.single.content, contains('third decision'));
  });

  test(
    'starts the next short chunk while the previous one transcribes',
    () async {
      final repository = CaptureSettingsRepository();
      await repository.save(
        const CaptureSettings(paused: false, captureAudio: true),
      );
      final firstChunk = Completer<void>();
      var captures = 0;
      final service = AudioCaptureService(
        memory: services.memory,
        settingsRepository: repository,
        modelRepository: _FakeModelRepository(),
        interval: const Duration(milliseconds: 10),
        readWindow: () => const WindowSnapshot(
          appName: 'teams.exe',
          windowTitle: 'Standup',
        ),
        readEnvironment: () async => const CaptureEnvironmentState(),
        recordAndTranscribe: (_, __) async {
          captures++;
          if (captures == 1) await firstChunk.future;
          return null;
        },
      );

      await service.start();
      await Future<void>.delayed(const Duration(milliseconds: 35));
      await service.stop();
      firstChunk.complete();

      expect(captures, greaterThan(1));
    },
    skip: !Platform.isWindows,
  );

  test('capture failures remain observable', () async {
    final failure = StateError('microphone unavailable');
    Object? reported;
    final repository = CaptureSettingsRepository();
    await repository.save(
      const CaptureSettings(paused: false, captureAudio: true),
    );
    final service = AudioCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      modelRepository: _FakeModelRepository(),
      readWindow: () => const WindowSnapshot(
        appName: 'teams.exe',
        windowTitle: 'Standup',
      ),
      readEnvironment: () async => const CaptureEnvironmentState(),
      recordAndTranscribe: (_, __) async => throw failure,
      onError: (error, _) => reported = error,
    );

    expect(await service.tick(), AudioCaptureOutcome.failed);
    expect(service.lastError, same(failure));
    expect(reported, same(failure));
  });

  test('preflight failures remain observable to the timer', () async {
    final failure = StateError('environment unavailable');
    Object? reported;
    final service = AudioCaptureService(
      memory: services.memory,
      settingsRepository: CaptureSettingsRepository(),
      modelRepository: _FakeModelRepository(),
      readEnvironment: () async => throw failure,
      onError: (error, _) => reported = error,
    );

    expect(await service.tickSafely(), AudioCaptureOutcome.failed);
    expect(service.lastError, same(failure));
    expect(reported, same(failure));
  });

  test('locked Windows prevents microphone capture', () async {
    final repository = CaptureSettingsRepository();
    await repository.save(
      const CaptureSettings(paused: false, captureAudio: true),
    );
    final service = AudioCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      modelRepository: _FakeModelRepository(),
      readEnvironment: () async => const CaptureEnvironmentState(locked: true),
      readWindow: () => throw StateError('must not inspect a locked desktop'),
      recordAndTranscribe: (_, __) async =>
          throw StateError('must not capture a locked microphone'),
    );

    expect(await service.tick(), AudioCaptureOutcome.disabled);
    expect(await database.allActivities(), isEmpty);
  });

  test('blocked sources prevent microphone capture', () async {
    final repository = CaptureSettingsRepository();
    await repository.save(
      const CaptureSettings(paused: false, captureAudio: true),
    );
    final sources = CaptureSourceRegistry();
    await sources.observe(
      const WindowSnapshot(appName: 'teams.exe', windowTitle: 'Standup'),
    );
    await sources.setEnabled('teams.exe', true);
    await sources.setBlocked('teams.exe', true);
    final service = AudioCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      sourceRegistry: sources,
      modelRepository: _FakeModelRepository(),
      readEnvironment: () async => const CaptureEnvironmentState(),
      readWindow: () => const WindowSnapshot(
        appName: 'teams.exe',
        windowTitle: 'Standup',
      ),
      recordAndTranscribe: (_, __) async =>
          throw StateError('must not record a blocked source'),
    );

    expect(await service.tick(), AudioCaptureOutcome.disabled);
    expect(await database.allActivities(), isEmpty);
  });

  group('WhisperModelRepository', () {
    test('reports a missing model as not downloaded', () async {
      final dir = Directory.systemTemp.createTempSync('kangoos_model');
      addTearDown(() => dir.deleteSync(recursive: true));

      final repository = WhisperModelRepository(modelDirectory: dir);
      expect(await repository.isDownloaded(), isFalse);
    });

    test('reports a truncated download as not downloaded', () async {
      final dir = Directory.systemTemp.createTempSync('kangoos_model');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/$whisperModelFileName').writeAsStringSync('nope');

      final repository = WhisperModelRepository(modelDirectory: dir);
      expect(await repository.isDownloaded(), isFalse);
    });
  });
}
