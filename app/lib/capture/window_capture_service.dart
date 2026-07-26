import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart' show Clipboard;
import 'package:kangoos_core/kangoos_core.dart';
import 'package:path/path.dart' as p;

import 'browser_url_reader_linux.dart';
import 'browser_url_reader_macos.dart';
import 'browser_url_reader_windows.dart';
import 'capture_settings_repository.dart';
import 'window_reader_linux.dart';
import 'window_reader_macos.dart';
import 'window_reader_windows.dart';
import 'window_snapshot.dart';

export 'window_snapshot.dart';

const uiaHelperTimeout = Duration(seconds: 3);
const maxCapturedClipboardLength = 2000;

class WindowCaptureService {
  WindowCaptureService({
    required this.database,
    required this.settingsRepository,
    this.pollInterval = const Duration(seconds: 5),
    WindowSnapshot? Function()? readWindow,
    Future<String?> Function()? captureVisibleText,
    Future<String?> Function(String appName)? browserUrlReader,
    Future<String?> Function()? clipboardReader,
  })  : readWindow = readWindow ?? defaultWindowReader(),
        captureVisibleText =
            captureVisibleText ?? _captureVisibleTextViaHelper,
        browserUrlReader = browserUrlReader ?? defaultBrowserUrlReader(),
        clipboardReader = clipboardReader ?? _readClipboard;

  final KangoosDatabase database;
  final CaptureSettingsRepository settingsRepository;
  final Duration pollInterval;

  /// Overridable for tests; defaults to the platform-appropriate reader.
  final WindowSnapshot? Function() readWindow;

  final Future<String?> Function() captureVisibleText;

  /// Overridable for tests; defaults to the platform-appropriate browser URL
  /// reader. Only called when [CaptureSettings.captureBrowserUrls] is on.
  final Future<String?> Function(String appName) browserUrlReader;

  final Future<String?> Function() clipboardReader;

  Timer? _timer;
  String? _lastKey;

  static bool get isSupported =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static WindowSnapshot? Function() defaultWindowReader() {
    if (Platform.isWindows) return readForegroundWindowWindows;
    if (Platform.isLinux) return readForegroundWindowLinux;
    if (Platform.isMacOS) return readForegroundWindowMacOS;
    return () => null;
  }

  static Future<String?> Function(String appName) defaultBrowserUrlReader() {
    if (Platform.isWindows) {
      return (appName) async => readBrowserUrlWindows(appName);
    }
    if (Platform.isMacOS) {
      return (appName) async => readBrowserUrlMacOS(appName);
    }
    if (Platform.isLinux) return readBrowserUrlLinux;
    return (_) async => null;
  }

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
    final url = settings.captureBrowserUrls
        ? await browserUrlReader(snapshot.appName)
        : null;
    final clipboard =
        settings.captureClipboard ? await clipboardReader() : null;

    await database.logActivity(ActivitiesCompanion.insert(
      appName: snapshot.appName,
      windowTitle: snapshot.windowTitle,
      capturedText: Value(visibleText),
      capturedUrl: Value(url),
      capturedClipboard: Value(clipboard),
    ));
  }

  static Future<String?> _readClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) return null;
      return text.length > maxCapturedClipboardLength
          ? text.substring(0, maxCapturedClipboardLength)
          : text;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _captureVisibleTextViaHelper() async {
    final helperPath = _resolveCompiledHelperPath();
    if (helperPath == null) return null;

    try {
      final process = await Process.start(helperPath, const []);
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

  static String? _resolveCompiledHelperPath() {
    if (!Platform.isWindows) return null;
    final helper =
        p.join(p.dirname(Platform.resolvedExecutable), 'uia_capture.exe');
    return File(helper).existsSync() ? helper : null;
  }
}
