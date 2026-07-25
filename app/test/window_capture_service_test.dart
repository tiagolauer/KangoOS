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
      readWindow: () => const WindowSnapshot(appName: 'a.exe', windowTitle: 'A'),
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
}
