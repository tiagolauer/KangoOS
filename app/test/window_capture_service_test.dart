import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kangoos_app/capture/capture_settings_repository.dart';
import 'package:kangoos_app/capture/window_capture_service.dart';

void main() {
  late KangoosDatabase database;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = KangoosDatabase.memory();
  });
  tearDown(() => database.close());

  test('tick logs a new window and skips consecutive duplicates', () async {
    var call = 0;
    final windows = [
      const WindowSnapshot(appName: 'code.exe', windowTitle: 'main.dart'),
      const WindowSnapshot(appName: 'code.exe', windowTitle: 'main.dart'),
      const WindowSnapshot(appName: 'chrome.exe', windowTitle: 'Docs'),
    ];
    final service = WindowCaptureService(
      database: database,
      settingsRepository: CaptureSettingsRepository(),
      readWindow: () => windows[call++],
    );

    await service.tick();
    await service.tick();
    await service.tick();

    final logged = await database.watchRecentActivities().first;
    expect(logged, hasLength(2));
    expect(logged.map((a) => a.windowTitle), ['Docs', 'main.dart']);
  });

  test('tick does nothing while capture is paused', () async {
    final repository = CaptureSettingsRepository();
    await repository.save(const CaptureSettings(paused: true));

    final service = WindowCaptureService(
      database: database,
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
      database: database,
      settingsRepository: repository,
      readWindow: () =>
          const WindowSnapshot(appName: 'keepass.exe', windowTitle: 'Vault'),
    );

    await service.tick();

    expect(await database.watchRecentActivities().first, isEmpty);
  });

  test('tick logs nothing when no foreground window is available', () async {
    final service = WindowCaptureService(
      database: database,
      settingsRepository: CaptureSettingsRepository(),
      readWindow: () => null,
    );

    await service.tick();

    expect(await database.watchRecentActivities().first, isEmpty);
  });

  test('tick purges activity older than the configured retention', () async {
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'old.exe',
      windowTitle: 'Old',
      capturedAt: Value(DateTime.now().subtract(const Duration(days: 40))),
    ));

    final repository = CaptureSettingsRepository();
    await repository
        .save(const CaptureSettings(paused: true, retentionDays: 30));

    final service = WindowCaptureService(
      database: database,
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
      database: database,
      settingsRepository: repository,
      readWindow: () =>
          const WindowSnapshot(appName: 'chrome.exe', windowTitle: 'Docs'),
      browserUrlReader: (appName) async => 'https://example.com',
    );

    await service.tick();

    final logged = await database.watchRecentActivities().first;
    expect(logged.single.capturedUrl, 'https://example.com');
  });

  test('tick does not call browserUrlReader when captureBrowserUrls is off',
      () async {
    final repository = CaptureSettingsRepository();
    var called = false;

    final service = WindowCaptureService(
      database: database,
      settingsRepository: repository,
      readWindow: () =>
          const WindowSnapshot(appName: 'chrome.exe', windowTitle: 'Docs'),
      browserUrlReader: (appName) async {
        called = true;
        return 'https://example.com';
      },
    );

    await service.tick();

    expect(called, isFalse);
    final logged = await database.watchRecentActivities().first;
    expect(logged.single.capturedUrl, isNull);
  });

  test('tick keeps history when retention is set to forever', () async {
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'old.exe',
      windowTitle: 'Old',
      capturedAt: Value(DateTime.now().subtract(const Duration(days: 400))),
    ));

    final repository = CaptureSettingsRepository();
    await repository
        .save(const CaptureSettings(paused: true, retentionDays: 0));

    final service = WindowCaptureService(
      database: database,
      settingsRepository: repository,
      readWindow: () => null,
    );

    await service.tick();

    expect(await database.watchRecentActivities().first, hasLength(1));
  });

  test('tick attaches visible text only when the setting is enabled',
      () async {
    final repository = CaptureSettingsRepository();
    await repository.save(const CaptureSettings(captureVisibleText: true));

    final service = WindowCaptureService(
      database: database,
      settingsRepository: repository,
      readWindow: () =>
          const WindowSnapshot(appName: 'code.exe', windowTitle: 'main.dart'),
      captureVisibleText: () async => 'typed content',
    );

    await service.tick();

    final logged = await database.watchRecentActivities().first;
    expect(logged.single.capturedText, 'typed content');
  });

  test('tick attaches screen OCR text only when the setting is enabled',
      () async {
    final repository = CaptureSettingsRepository();
    await repository.save(const CaptureSettings(captureScreenText: true));

    final service = WindowCaptureService(
      database: database,
      settingsRepository: repository,
      readWindow: () =>
          const WindowSnapshot(appName: 'code.exe', windowTitle: 'main.dart'),
      captureScreenText: () async => 'text read off the screen',
    );

    await service.tick();

    final logged = await database.watchRecentActivities().first;
    expect(logged.single.capturedScreenText, 'text read off the screen');
  });

  test('tick never runs screen OCR when the setting is disabled', () async {
    final service = WindowCaptureService(
      database: database,
      settingsRepository: CaptureSettingsRepository(),
      readWindow: () =>
          const WindowSnapshot(appName: 'code.exe', windowTitle: 'main.dart'),
      captureScreenText: () async =>
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
      database: database,
      settingsRepository: repository,
      readWindow: () =>
          const WindowSnapshot(appName: 'code.exe', windowTitle: 'main.dart'),
      captureScreenText: () async => 'quarterly revenue projection',
    );
    await service.tick();

    final hits = await database.searchActivities('quarterly');
    expect(hits, hasLength(1));
    expect(hits.single.windowTitle, 'main.dart');
  });

  test('tick leaves capturedText null when the setting is disabled',
      () async {
    final service = WindowCaptureService(
      database: database,
      settingsRepository: CaptureSettingsRepository(),
      readWindow: () =>
          const WindowSnapshot(appName: 'code.exe', windowTitle: 'main.dart'),
      captureVisibleText: () async =>
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
      database: database,
      settingsRepository: repository,
      readWindow: () =>
          const WindowSnapshot(appName: 'code.exe', windowTitle: 'main.dart'),
      captureVisibleText: () async => null,
    );

    await service.tick();

    final logged = await database.watchRecentActivities().first;
    expect(logged.single.capturedText, isNull);
  });

  test('tick records the clipboard when captureClipboard is on', () async {
    final repository = CaptureSettingsRepository();
    await repository.save(const CaptureSettings(captureClipboard: true));

    final service = WindowCaptureService(
      database: database,
      settingsRepository: repository,
      readWindow: () =>
          const WindowSnapshot(appName: 'code.exe', windowTitle: 'main.dart'),
      clipboardReader: () async => 'copied text',
    );

    await service.tick();

    final logged = await database.watchRecentActivities().first;
    expect(logged.single.capturedClipboard, 'copied text');
  });

  test('tick does not call clipboardReader when captureClipboard is off',
      () async {
    var called = false;
    final service = WindowCaptureService(
      database: database,
      settingsRepository: CaptureSettingsRepository(),
      readWindow: () =>
          const WindowSnapshot(appName: 'code.exe', windowTitle: 'main.dart'),
      clipboardReader: () async {
        called = true;
        return 'copied text';
      },
    );

    await service.tick();

    expect(called, isFalse);
    final logged = await database.watchRecentActivities().first;
    expect(logged.single.capturedClipboard, isNull);
  });
}
