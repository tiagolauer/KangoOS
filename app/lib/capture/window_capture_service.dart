import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

import 'capture_settings_repository.dart';

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
  }) : readWindow = readWindow ?? readForegroundWindow;

  final KangoosDatabase database;
  final CaptureSettingsRepository settingsRepository;
  final Duration pollInterval;

  /// Overridable for tests; defaults to the real [readForegroundWindow].
  final WindowSnapshot? Function() readWindow;

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

    await database.logActivity(ActivitiesCompanion.insert(
      appName: snapshot.appName,
      windowTitle: snapshot.windowTitle,
    ));
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
