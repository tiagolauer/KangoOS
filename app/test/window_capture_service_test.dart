import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kangoos_app/capture/capture_settings_repository.dart';
import 'package:kangoos_app/capture/capture_environment.dart';
import 'package:kangoos_app/capture/capture_source_registry.dart';
import 'package:kangoos_app/capture/window_capture_service.dart';

import 'test_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const windowChannel = MethodChannel('kangoos/window');
  late KangoosDatabase database;
  late TestServices services;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      windowChannel,
      (_) async => {'locked': false, 'idleMilliseconds': 0},
    );
    final sources = CaptureSourceRegistry();
    for (final appName in const [
      'code.exe',
      'chrome.exe',
      'keepass.exe',
      'KeePass.exe',
      'a.exe',
    ]) {
      await sources.observe(
        WindowSnapshot(appName: appName, windowTitle: 'Allowed'),
      );
      await sources.setEnabled(appName, true);
    }
    database = KangoosDatabase.memory();
    services = TestServices(database);
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowChannel, null);
    await database.close();
  });

  test('tick logs a new window and skips consecutive duplicates', () async {
    var call = 0;
    final windows = [
      const WindowSnapshot(appName: 'code.exe', windowTitle: 'main.dart'),
      const WindowSnapshot(appName: 'code.exe', windowTitle: 'main.dart'),
      const WindowSnapshot(appName: 'code.exe', windowTitle: 'main.dart'),
      const WindowSnapshot(appName: 'chrome.exe', windowTitle: 'Docs'),
      const WindowSnapshot(appName: 'chrome.exe', windowTitle: 'Docs'),
    ];
    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: CaptureSettingsRepository(),
      readWindow: () => windows[call++],
    );

    await service.tick();
    await service.tick();
    await service.tick();

    final logged = await database.watchRecentActivities().first;
    expect(logged, hasLength(2));
    expect(logged.map((a) => a.windowTitle), ['Docs', 'main.dart']);
    expect(logged.map((a) => a.sourceId), ['chrome.exe', 'code.exe']);
  });

  test('excluded apps match regardless of case', () async {
    final repository = CaptureSettingsRepository();
    await repository.save(const CaptureSettings(excludedApps: ['keepass.exe']));

    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      readWindow: () => const WindowSnapshot(
        appName: 'KeePass.exe',
        windowTitle: 'Vault',
      ),
    );

    await service.tick();

    expect(await database.watchRecentActivities().first, isEmpty);
  });

  test('a slow tick does not overlap with the next one', () async {
    final repository = CaptureSettingsRepository();
    await repository.save(const CaptureSettings(captureVisibleText: true));

    final blocked = Completer<String?>();
    var windowReads = 0;
    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      readWindow: () {
        windowReads++;
        return WindowSnapshot(
          appName: 'code.exe',
          windowTitle: 'window $windowReads',
        );
      },
      captureVisibleText: (_) => blocked.future,
    );

    final first = service.tickSafely();
    await Future<void>.delayed(Duration.zero);
    await service.tickSafely();

    expect(windowReads, 1);

    blocked.complete('visible text');
    await first;

    expect(await database.watchRecentActivities().first, hasLength(1));
  });

  test('a throwing tick is reported instead of escaping the timer', () async {
    final errors = <Object>[];
    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: CaptureSettingsRepository(),
      readWindow: () => throw StateError('window reader exploded'),
      onError: (error, _) => errors.add(error),
    );

    await service.tickSafely();

    await service.tickSafely();

    expect(errors, hasLength(2));
    expect(errors.first, isA<StateError>());
  });

  test('tick does nothing while capture is paused', () async {
    final repository = CaptureSettingsRepository();
    await repository.save(const CaptureSettings(paused: true));

    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      readWindow: () =>
          const WindowSnapshot(appName: 'a.exe', windowTitle: 'A'),
    );

    await service.tick();

    expect(await database.watchRecentActivities().first, isEmpty);
  });

  test('tick skips excluded apps', () async {
    final repository = CaptureSettingsRepository();
    await repository.save(const CaptureSettings(excludedApps: ['keepass.exe']));

    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      readWindow: () => const WindowSnapshot(
        appName: 'keepass.exe',
        windowTitle: 'Vault',
      ),
    );

    await service.tick();

    expect(await database.watchRecentActivities().first, isEmpty);
  });

  test('tick logs nothing when no foreground window is available', () async {
    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: CaptureSettingsRepository(),
      readWindow: () => null,
    );

    await service.tick();

    expect(await database.watchRecentActivities().first, isEmpty);
  });

  test('tick purges activity older than the configured retention', () async {
    await database.logActivity(
      ActivitiesCompanion.insert(
        appName: 'old.exe',
        windowTitle: 'Old',
        capturedAt: Value(DateTime.now().subtract(const Duration(days: 40))),
      ),
    );

    final repository = CaptureSettingsRepository();
    await repository.save(
      const CaptureSettings(paused: true, retentionDays: 30),
    );

    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      readWindow: () => null,
    );

    await service.tick();

    expect(await database.watchRecentActivities().first, isEmpty);
  });

  test('tick records the browser URL when captureBrowserUrls is on', () async {
    final repository = CaptureSettingsRepository();
    await repository.save(const CaptureSettings(captureBrowserUrls: true));

    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      readWindow: () =>
          const WindowSnapshot(appName: 'chrome.exe', windowTitle: 'Docs'),
      browserUrlReader: (appName) async => 'https://example.com',
    );

    await service.tick();

    final logged = await database.watchRecentActivities().first;
    expect(logged.single.capturedUrl, 'https://example.com');
  });

  test(
    'tick does not call browserUrlReader when captureBrowserUrls is off',
    () async {
      final repository = CaptureSettingsRepository();
      var called = false;

      final service = WindowCaptureService(
        memory: services.memory,
        settingsRepository: repository,
        readWindow: () => const WindowSnapshot(
          appName: 'chrome.exe',
          windowTitle: 'Docs',
        ),
        browserUrlReader: (appName) async {
          called = true;
          return 'https://example.com';
        },
      );

      await service.tick();

      expect(called, isFalse);
      final logged = await database.watchRecentActivities().first;
      expect(logged.single.capturedUrl, isNull);
    },
  );

  test('tick keeps history when retention is set to forever', () async {
    await database.logActivity(
      ActivitiesCompanion.insert(
        appName: 'old.exe',
        windowTitle: 'Old',
        capturedAt: Value(DateTime.now().subtract(const Duration(days: 400))),
      ),
    );

    final repository = CaptureSettingsRepository();
    await repository.save(
      const CaptureSettings(paused: true, retentionDays: 0),
    );

    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      readWindow: () => null,
    );

    await service.tick();

    expect(await database.watchRecentActivities().first, hasLength(1));
  });

  test('tick attaches visible text only when the setting is enabled', () async {
    final repository = CaptureSettingsRepository();
    await repository.save(const CaptureSettings(captureVisibleText: true));

    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      readWindow: () => const WindowSnapshot(
        appName: 'code.exe',
        windowTitle: 'main.dart',
      ),
      captureVisibleText: (_) async => 'typed content',
    );

    await service.tick();

    final logged = await database.watchRecentActivities().first;
    expect(logged.single.capturedText, 'typed content');
  });

  test(
    'tick attaches screen OCR text only when the setting is enabled',
    () async {
      final repository = CaptureSettingsRepository();
      await repository.save(const CaptureSettings(captureScreenText: true));
      WindowSnapshot? ocrTarget;

      final service = WindowCaptureService(
        memory: services.memory,
        settingsRepository: repository,
        readWindow: () => const WindowSnapshot(
          appName: 'code.exe',
          windowTitle: 'main.dart',
        ),
        captureScreenText: (snapshot) async {
          ocrTarget = snapshot;
          return 'text read off the screen';
        },
      );

      await service.tick();

      final logged = await database.watchRecentActivities().first;
      expect(logged.single.capturedScreenText, 'text read off the screen');
      expect(ocrTarget?.appId, 'code.exe');
    },
  );

  test('tick never runs screen OCR when the setting is disabled', () async {
    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: CaptureSettingsRepository(),
      readWindow: () => const WindowSnapshot(
        appName: 'code.exe',
        windowTitle: 'main.dart',
      ),
      captureScreenText: (_) async =>
          throw StateError('should not be called when disabled'),
    );

    await service.tick();

    final logged = await database.watchRecentActivities().first;
    expect(logged.single.capturedScreenText, isNull);
  });

  test('screen OCR text is full-text searchable', () async {
    final repository = CaptureSettingsRepository();
    await repository.save(const CaptureSettings(captureScreenText: true));

    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      readWindow: () => const WindowSnapshot(
        appName: 'code.exe',
        windowTitle: 'main.dart',
      ),
      captureScreenText: (_) async => 'quarterly revenue projection',
    );
    await service.tick();

    final hits = await database.searchActivities('quarterly');
    expect(hits, hasLength(1));
    expect(hits.single.windowTitle, 'main.dart');
  });

  test('tick leaves capturedText null when the setting is disabled', () async {
    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: CaptureSettingsRepository(),
      readWindow: () => const WindowSnapshot(
        appName: 'code.exe',
        windowTitle: 'main.dart',
      ),
      captureVisibleText: (_) async =>
          throw StateError('should not be called when disabled'),
    );

    await service.tick();

    final logged = await database.watchRecentActivities().first;
    expect(logged.single.capturedText, isNull);
  });

  test('tick leaves capturedText null when the helper fails', () async {
    final repository = CaptureSettingsRepository();
    await repository.save(const CaptureSettings(captureVisibleText: true));

    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      readWindow: () => const WindowSnapshot(
        appName: 'code.exe',
        windowTitle: 'main.dart',
      ),
      captureVisibleText: (_) async => null,
    );

    await service.tick();

    final logged = await database.watchRecentActivities().first;
    expect(logged.single.capturedText, isNull);
  });

  test('tick records the clipboard when captureClipboard is on', () async {
    final repository = CaptureSettingsRepository();
    await repository.save(const CaptureSettings(captureClipboard: true));

    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      readWindow: () => const WindowSnapshot(
        appName: 'code.exe',
        windowTitle: 'main.dart',
      ),
      clipboardReader: () async => 'copied text',
    );

    await service.tick();

    final logged = await database.watchRecentActivities().first;
    expect(logged.single.capturedClipboard, 'copied text');
  });

  test(
    'tick does not call clipboardReader when captureClipboard is off',
    () async {
      var called = false;
      final service = WindowCaptureService(
        memory: services.memory,
        settingsRepository: CaptureSettingsRepository(),
        readWindow: () => const WindowSnapshot(
          appName: 'code.exe',
          windowTitle: 'main.dart',
        ),
        clipboardReader: () async {
          called = true;
          return 'copied text';
        },
      );

      await service.tick();

      expect(called, isFalse);
      final logged = await database.watchRecentActivities().first;
      expect(logged.single.capturedClipboard, isNull);
    },
  );

  test('clipboard changes are captured without changing windows', () async {
    final repository = CaptureSettingsRepository();
    await repository.save(const CaptureSettings(captureClipboard: true));
    var clipboard = 'first copy';
    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      readWindow: () => const WindowSnapshot(
        appName: 'code.exe',
        windowTitle: 'main.dart',
      ),
      clipboardReader: () async => clipboard,
    );

    await service.tick();
    clipboard = 'second copy';
    await service.tick();
    await service.tick();

    final logged = await database.allActivities();
    expect(logged, hasLength(2));
    expect(logged.map((activity) => activity.capturedClipboard), [
      'first copy',
      'second copy',
    ]);
  });

  test('new sources are discovered disabled and capture nothing', () async {
    final sources = CaptureSourceRegistry();
    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: CaptureSettingsRepository(),
      sourceRegistry: sources,
      readWindow: () =>
          const WindowSnapshot(appName: 'new.exe', windowTitle: 'New app'),
    );

    await service.tick();

    expect(await database.allActivities(), isEmpty);
    final source = (await sources.list()).singleWhere(
      (candidate) => candidate.id == 'new.exe',
    );
    expect(source.id, 'new.exe');
    expect(source.enabled, isFalse);
  });

  test(
    'clipboard copied in a blocked source never leaks to another app',
    () async {
      final repository = CaptureSettingsRepository();
      await repository.save(const CaptureSettings(captureClipboard: true));
      final sources = CaptureSourceRegistry();
      await sources.observe(
        const WindowSnapshot(appName: 'vault.exe', windowTitle: 'Vault'),
      );
      await sources.setEnabled('vault.exe', true);
      await sources.setBlocked('vault.exe', true);
      var snapshot = const WindowSnapshot(
        appName: 'vault.exe',
        windowTitle: 'Vault',
      );
      final service = WindowCaptureService(
        memory: services.memory,
        settingsRepository: repository,
        sourceRegistry: sources,
        readWindow: () => snapshot,
        clipboardReader: () async => 'secret copied in vault',
      );

      await service.tick();
      snapshot = const WindowSnapshot(
        appName: 'code.exe',
        windowTitle: 'main.dart',
      );
      await service.tick();

      final logged = await database.allActivities();
      expect(logged, hasLength(1));
      expect(logged.single.appName, 'code.exe');
      expect(logged.single.capturedClipboard, isNull);
    },
  );

  test('blocked sources skip metadata, text, OCR, URL and clipboard', () async {
    final repository = CaptureSettingsRepository();
    await repository.save(
      const CaptureSettings(
        captureVisibleText: true,
        captureScreenText: true,
        captureBrowserUrls: true,
        captureClipboard: true,
      ),
    );
    final sources = CaptureSourceRegistry();
    await sources.observe(
      const WindowSnapshot(appName: 'vault.exe', windowTitle: 'Secret'),
    );
    await sources.setEnabled('vault.exe', true);
    await sources.setBlocked('vault.exe', true);
    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      sourceRegistry: sources,
      readWindow: () =>
          const WindowSnapshot(appName: 'vault.exe', windowTitle: 'Secret'),
      clipboardReader: () async => 'secret clipboard',
      captureVisibleText: (_) async =>
          throw StateError('must not read blocked UI text'),
      captureScreenText: (_) async =>
          throw StateError('must not OCR a blocked source'),
      browserUrlReader: (_) async =>
          throw StateError('must not read a blocked URL'),
    );

    await service.tick();

    expect(await database.allActivities(), isEmpty);
  });

  test('locked Windows suspends every capture modality', () async {
    final repository = CaptureSettingsRepository();
    await repository.save(
      const CaptureSettings(captureClipboard: true, captureScreenText: true),
    );
    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      readEnvironment: () async => const CaptureEnvironmentState(locked: true),
      readWindow: () => throw StateError('must not read a locked desktop'),
      clipboardReader: () async =>
          throw StateError('must not read a locked clipboard'),
      captureScreenText: (_) async =>
          throw StateError('must not OCR a locked desktop'),
    );

    await service.tick();

    expect(await database.allActivities(), isEmpty);
  });

  test('idle mode reduces window capture frequency', () async {
    final repository = CaptureSettingsRepository();
    var current = DateTime.utc(2026, 8, 26, 10);
    var title = 'First';
    final service = WindowCaptureService(
      memory: services.memory,
      settingsRepository: repository,
      now: () => current,
      idleInterval: const Duration(seconds: 30),
      readEnvironment: () async =>
          const CaptureEnvironmentState(idleFor: Duration(minutes: 10)),
      readWindow: () => WindowSnapshot(appName: 'code.exe', windowTitle: title),
    );

    await service.tick();
    current = current.add(const Duration(seconds: 5));
    title = 'Second';
    await service.tick();
    current = current.add(const Duration(seconds: 31));
    title = 'Third';
    await service.tick();

    final logged = await database.allActivities();
    expect(logged.map((activity) => activity.windowTitle), ['First', 'Third']);
  });
}
