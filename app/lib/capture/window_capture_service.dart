import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:kangoos_core/kangoos_core.dart';

import 'browser_url_reader_linux.dart';
import 'browser_url_reader_macos.dart';
import 'browser_url_reader_windows.dart';
import 'capture_settings_repository.dart';
import 'window_reader_linux.dart';
import 'window_reader_macos.dart';
import 'window_reader_windows.dart';
import 'window_snapshot.dart';

export 'window_snapshot.dart';

class WindowCaptureService {
  WindowCaptureService({
    required this.database,
    required this.settingsRepository,
    this.pollInterval = const Duration(seconds: 5),
    WindowSnapshot? Function()? readWindow,
    Future<String?> Function(String appName)? browserUrlReader,
  })  : readWindow = readWindow ?? defaultWindowReader(),
        browserUrlReader = browserUrlReader ?? defaultBrowserUrlReader();

  final KangoosDatabase database;
  final CaptureSettingsRepository settingsRepository;
  final Duration pollInterval;

  /// Overridable for tests; defaults to the platform-appropriate reader.
  final WindowSnapshot? Function() readWindow;

  /// Overridable for tests; defaults to the platform-appropriate browser URL
  /// reader. Only called when [CaptureSettings.captureBrowserUrls] is on.
  final Future<String?> Function(String appName) browserUrlReader;

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

    final url = settings.captureBrowserUrls
        ? await browserUrlReader(snapshot.appName)
        : null;

    await database.logActivity(ActivitiesCompanion.insert(
      appName: snapshot.appName,
      windowTitle: snapshot.windowTitle,
      capturedText: url == null ? const Value.absent() : Value(url),
    ));
  }
}
