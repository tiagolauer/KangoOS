import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kangoos_app/capture/audio_capture_service.dart';
import 'package:kangoos_app/capture/capture_environment.dart';
import 'package:kangoos_app/capture/capture_settings_repository.dart';
import 'package:kangoos_app/capture/capture_source_registry.dart';
import 'package:kangoos_app/capture/window_capture_service.dart';
import 'package:kangoos_app/capture/window_reader_windows.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:win32/win32.dart';

const _ocrMarker = 'KANGO NATIVE OCR 8427';
const _clipboardMarker = 'KANGO_NATIVE_CLIPBOARD_8427';

bool _forceForeground(int windowHandle) {
  final currentThread = GetCurrentThreadId();
  final foregroundThread = GetWindowThreadProcessId(
    GetForegroundWindow(),
    nullptr,
  );
  final targetThread = GetWindowThreadProcessId(windowHandle, nullptr);
  if (foregroundThread != currentThread) {
    AttachThreadInput(currentThread, foregroundThread, TRUE);
  }
  if (targetThread != currentThread && targetThread != foregroundThread) {
    AttachThreadInput(currentThread, targetThread, TRUE);
  }
  try {
    ShowWindow(windowHandle, SHOW_WINDOW_CMD.SW_RESTORE);
    SetWindowPos(
      windowHandle,
      HWND_TOPMOST,
      0,
      0,
      0,
      0,
      SET_WINDOW_POS_FLAGS.SWP_NOMOVE |
          SET_WINDOW_POS_FLAGS.SWP_NOSIZE |
          SET_WINDOW_POS_FLAGS.SWP_SHOWWINDOW,
    );
    SwitchToThisWindow(windowHandle, TRUE);
    BringWindowToTop(windowHandle);
    SetForegroundWindow(windowHandle);
    SetFocus(windowHandle);
    SetWindowPos(
      windowHandle,
      HWND_NOTOPMOST,
      0,
      0,
      0,
      0,
      SET_WINDOW_POS_FLAGS.SWP_NOMOVE | SET_WINDOW_POS_FLAGS.SWP_NOSIZE,
    );
    return GetForegroundWindow() == windowHandle;
  } finally {
    if (targetThread != currentThread && targetThread != foregroundThread) {
      AttachThreadInput(currentThread, targetThread, FALSE);
    }
    if (foregroundThread != currentThread) {
      AttachThreadInput(currentThread, foregroundThread, FALSE);
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Windows captures native window, clipboard and OCR and blocks denied data',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final database = KangoosDatabase.memory();
      final previousClipboard = await Clipboard.getData(Clipboard.kTextPlain);
      final audioFile = File(
        '${Directory.systemTemp.path}\\kangoos_m8_native_audio.wav',
      );
      addTearDown(() async {
        await Clipboard.setData(
          ClipboardData(text: previousClipboard?.text ?? ''),
        );
        if (await audioFile.exists()) await audioFile.delete();
        await database.close();
      });

      await windowManager.ensureInitialized();
      await windowManager.setTitle(_ocrMarker);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.show();
      await windowManager.focus();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text(_ocrMarker, style: TextStyle(fontSize: 36)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final title = _ocrMarker.toNativeUtf16();
      final int windowHandle;
      try {
        windowHandle = FindWindow(nullptr, title);
      } finally {
        calloc.free(title);
      }
      expect(windowHandle, isNot(0));
      expect(_forceForeground(windowHandle), isTrue);
      await tester.pump(const Duration(milliseconds: 500));

      final environment = await CaptureEnvironment.read();
      expect(environment.locked, isFalse);
      final snapshot = readForegroundWindowWindows();
      expect(snapshot, isNotNull);
      expect(snapshot!.nativeWindowId, windowHandle);

      final activities = SqliteActivityRepository(database);
      final memory = MemoryService(
        database: database,
        activities: activities,
        summaries: SqliteSummaryRepository(database),
      );
      final settings = CaptureSettingsRepository();
      await settings.save(
        const CaptureSettings(
          retentionDays: 0,
          captureScreenText: true,
          captureClipboard: true,
        ),
      );
      final sources = CaptureSourceRegistry();
      await sources.observe(snapshot);
      await sources.setEnabled(snapshot.appId, true);
      await Clipboard.setData(const ClipboardData(text: _clipboardMarker));

      final service = WindowCaptureService(
        memory: memory,
        settingsRepository: settings,
        sourceRegistry: sources,
        readWindow: () => snapshot,
      );
      await service.tick();
      final captured = await activities.all();
      expect(captured, hasLength(1));
      expect(captured.single.capturedClipboard, _clipboardMarker);
      expect(
        captured.single.capturedScreenText?.toUpperCase(),
        contains('KANGO'),
      );
      expect(captured.single.capturedScreenText, contains('8427'));

      await sources.setBlocked(snapshot.appId, true);
      await Clipboard.setData(
        const ClipboardData(text: 'KANGO_BLOCKED_SECRET_8427'),
      );
      await service.tick();
      expect(await activities.all(), hasLength(1));

      final lockedService = WindowCaptureService(
        memory: memory,
        settingsRepository: settings,
        sourceRegistry: sources,
        readEnvironment:
            () async => const CaptureEnvironmentState(locked: true),
        readWindow: () => throw StateError('locked window must not be read'),
      );
      await lockedService.tick();
      expect(await activities.all(), hasLength(1));

      final helper = File(
        '${File(Platform.resolvedExecutable).parent.path}\\audio_capture.exe',
      );
      expect(await helper.exists(), isTrue);
      final audio = await Process.run(helper.path, [audioFile.path, '1']);
      expect(audio.exitCode, anyOf(0, audioCaptureSilentExitCode));
      if (audio.exitCode == 0) {
        expect(await audioFile.length(), greaterThan(44));
      }
    },
    skip: !Platform.isWindows,
  );
}
