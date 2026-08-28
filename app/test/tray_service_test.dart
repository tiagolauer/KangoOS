import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_app/capture/capture_settings_repository.dart';
import 'package:kangoos_app/tray/tray_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const windowChannel = MethodChannel('window_manager');
  const trayChannel = MethodChannel('tray_manager');
  const kangoosWindowChannel = MethodChannel('kangoos/window');
  final windowCalls = <String>[];

  setUp(() {
    windowCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowChannel, (call) async {
      windowCalls.add(call.method);
      if (call.method == 'isFullScreen' ||
          call.method == 'isMaximized' ||
          call.method == 'isMinimized') {
        return false;
      }
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(trayChannel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kangoosWindowChannel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(trayChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kangoosWindowChannel, null);
  });

  test('initializes native taskbar support before tray window operations',
      () async {
    final service = TrayService(
      captureSettingsRepository: CaptureSettingsRepository(),
    );
    addTearDown(service.dispose);

    await service.init();

    expect(
      windowCalls,
      containsAllInOrder([
        'ensureInitialized',
        'waitUntilReadyToShow',
        'setPreventClose',
      ]),
    );
  }, skip: !Platform.isWindows);
}
