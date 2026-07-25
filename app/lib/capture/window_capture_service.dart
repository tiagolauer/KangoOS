import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:ffi/ffi.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

import 'capture_settings_repository.dart';

const uiaHelperTimeout = Duration(seconds: 3);

class WindowSnapshot {
  const WindowSnapshot({required this.appName, required this.windowTitle});

  final String appName;
  final String windowTitle;
}

class WindowCaptureService {
  WindowCaptureService({
    required this.database,
    required this.settingsRepository,
    this.pollInterval = const Duration(seconds: 5),
    WindowSnapshot? Function()? readWindow,
    Future<String?> Function()? captureVisibleText,
  })  : readWindow = readWindow ?? readForegroundWindow,
        captureVisibleText = captureVisibleText ?? _captureVisibleTextViaHelper;

  final KangoosDatabase database;
  final CaptureSettingsRepository settingsRepository;
  final Duration pollInterval;

  final WindowSnapshot? Function() readWindow;
  final Future<String?> Function() captureVisibleText;

  Timer? _timer;
  String? _lastKey;

  static bool get isSupported => Platform.isWindows;

  void start() {
    if (!isSupported || _timer != null) return;
    _timer = Timer.periodic(pollInterval, (_) => tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> tick() async {
    final settings = await settingsRepository.load();
    if (settings.retentionDays > 0) {
      await database.purgeActivitiesOlderThan(
        DateTime.now().subtract(Duration(days: settings.retentionDays)),
      );
    }
    if (settings.paused) return;

    final snapshot = readWindow();
    if (snapshot == null) return;
    if (settings.excludedApps.contains(snapshot.appName)) return;

    final key = '${snapshot.appName}|${snapshot.windowTitle}';
    if (key == _lastKey) return;
    _lastKey = key;

    final visibleText =
        settings.captureVisibleText ? await captureVisibleText() : null;

    await database.logActivity(ActivitiesCompanion.insert(
      appName: snapshot.appName,
      windowTitle: snapshot.windowTitle,
      capturedText: Value(visibleText),
    ));
  }

  static Future<String?> _captureVisibleTextViaHelper() async {
    try {
      final process = await Process.start(
        'dart',
        ['run', 'bin/uia_capture.dart'],
        workingDirectory: Directory.current.path,
      );
      final stdoutFuture = process.stdout.transform(utf8.decoder).join();
      final stderrDrained = process.stderr.drain<void>();

      final exitCode = await process.exitCode.timeout(
        uiaHelperTimeout,
        onTimeout: () {
          process.kill();
          return -1;
        },
      );
      await stderrDrained;
      if (exitCode != 0) return null;

      final text = (await stdoutFuture).trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  static WindowSnapshot? readForegroundWindow() {
    final hwnd = GetForegroundWindow();
    if (hwnd == 0) return null;

    final title = _windowTitle(hwnd);
    if (title == null || title.trim().isEmpty) return null;

    return WindowSnapshot(appName: _processName(hwnd), windowTitle: title);
  }

  static String? _windowTitle(int hwnd) {
    final length = GetWindowTextLength(hwnd);
    if (length == 0) return null;

    final buffer = wsalloc(length + 1);
    try {
      GetWindowText(hwnd, buffer, length + 1);
      return buffer.toDartString();
    } finally {
      free(buffer);
    }
  }

  static String _processName(int hwnd) {
    final pidPtr = calloc<Uint32>();
    final int pid;
    try {
      GetWindowThreadProcessId(hwnd, pidPtr);
      pid = pidPtr.value;
    } finally {
      free(pidPtr);
    }

    final process = OpenProcess(
      PROCESS_ACCESS_RIGHTS.PROCESS_QUERY_LIMITED_INFORMATION,
      0,
      pid,
    );
    if (process == 0) return 'pid:$pid';

    try {
      final sizePtr = calloc<Uint32>()..value = MAX_PATH;
      final nameBuffer = wsalloc(MAX_PATH);
      try {
        final ok = QueryFullProcessImageName(process, 0, nameBuffer, sizePtr);
        return ok == 0 ? 'pid:$pid' : p.basename(nameBuffer.toDartString());
      } finally {
        free(sizePtr);
        free(nameBuffer);
      }
    } finally {
      CloseHandle(process);
    }
  }
}
