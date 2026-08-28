import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show Clipboard;
import 'package:kangoos_core/kangoos_core.dart';
import 'package:path/path.dart' as p;

import '../runtime/runtime_service.dart';
import 'browser_url_reader_linux.dart';
import 'browser_url_reader_macos.dart';
import 'browser_url_reader_windows.dart';
import 'capture_environment.dart';
import 'capture_settings_repository.dart';
import 'capture_source_registry.dart';
import 'capture_status.dart';
import 'window_reader_linux.dart';
import 'window_reader_macos.dart';
import 'window_reader_windows.dart';
import 'window_snapshot.dart';

export 'window_snapshot.dart';

const uiaHelperTimeout = Duration(seconds: 3);
const screenOcrTimeout = Duration(seconds: 15);
const maxCapturedClipboardLength = 2000;
const captureIdleThreshold = Duration(minutes: 5);
const idleCaptureInterval = Duration(seconds: 30);

class WindowCaptureService implements RuntimeService {
  WindowCaptureService({
    required this.memory,
    required this.settingsRepository,
    CaptureSourceRegistry? sourceRegistry,
    this.captureStatus,
    this.pollInterval = const Duration(seconds: 5),
    this.idleThreshold = captureIdleThreshold,
    this.idleInterval = idleCaptureInterval,
    WindowSnapshot? Function()? readWindow,
    Future<String?> Function(WindowSnapshot snapshot)? captureVisibleText,
    Future<String?> Function(WindowSnapshot snapshot)? captureScreenText,
    Future<String?> Function(String appName)? browserUrlReader,
    Future<String?> Function()? clipboardReader,
    CaptureEnvironmentReader? readEnvironment,
    DateTime Function()? now,
    void Function(Object error, StackTrace stackTrace)? onError,
  })  : sourceRegistry = sourceRegistry ?? CaptureSourceRegistry(),
        onError = onError ?? _reportError,
        readWindow = readWindow ?? defaultWindowReader(),
        captureVisibleText = captureVisibleText ?? _captureVisibleTextViaHelper,
        captureScreenText = captureScreenText ?? _captureScreenTextViaHelper,
        browserUrlReader = browserUrlReader ?? defaultBrowserUrlReader(),
        clipboardReader = clipboardReader ?? _readClipboard,
        readEnvironment = readEnvironment ?? CaptureEnvironment.read,
        now = now ?? DateTime.now;

  final MemoryService memory;
  final CaptureSettingsRepository settingsRepository;
  final CaptureSourceRegistry sourceRegistry;
  final CaptureStatusController? captureStatus;
  final Duration pollInterval;
  final Duration idleThreshold;
  final Duration idleInterval;
  final WindowSnapshot? Function() readWindow;
  final Future<String?> Function(WindowSnapshot snapshot) captureVisibleText;
  final Future<String?> Function(WindowSnapshot snapshot) captureScreenText;
  final Future<String?> Function(String appName) browserUrlReader;
  final Future<String?> Function() clipboardReader;
  final CaptureEnvironmentReader readEnvironment;
  final DateTime Function() now;
  final void Function(Object error, StackTrace stackTrace) onError;

  Timer? _timer;
  String? _lastWindowKey;
  String? _lastClipboardHash;
  DateTime? _lastIdleCaptureAt;
  var _clipboardRequiresBaseline = false;
  var _ticking = false;

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

  @override
  Future<void> start() async {
    if (!isSupported || _timer != null) return;
    unawaited(tickSafely());
    _timer = Timer.periodic(pollInterval, (_) => tickSafely());
  }

  Future<void> tickSafely() async {
    if (_ticking) return;
    _ticking = true;
    try {
      await tick();
    } catch (error, stackTrace) {
      onError(error, stackTrace);
    } finally {
      _ticking = false;
    }
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    captureStatus?.setOcrActive(false);
  }

  Future<void> tick() async {
    final settings = await settingsRepository.load();
    final capturedAt = now();
    if (settings.retentionDays > 0) {
      await memory.purgeOlderThan(
        capturedAt.subtract(Duration(days: settings.retentionDays)),
      );
    }

    final environment = await readEnvironment();
    final idle = environment.idleFor >= idleThreshold;
    captureStatus?.setEnvironment(environment, idle: idle);
    if (settings.paused || environment.locked) {
      _clipboardRequiresBaseline = true;
      return;
    }

    final snapshot = readWindow();
    if (snapshot == null) return;
    final source = await sourceRegistry.observe(snapshot);
    final clipboard = settings.captureClipboard
        ? await _captureSafely(clipboardReader)
        : null;
    final clipboardHash = clipboard == null ? null : _hashClipboard(clipboard);
    var clipboardChanged = clipboardHash != _lastClipboardHash;
    if (settings.captureClipboard) {
      _lastClipboardHash = clipboardHash;
      if (_clipboardRequiresBaseline) clipboardChanged = false;
      _clipboardRequiresBaseline = false;
    }

    if (!source.canCapture ||
        isExcluded(snapshot.appName, settings.excludedApps, snapshot.appId)) {
      return;
    }

    if (idle && !clipboardChanged) {
      final lastIdleCaptureAt = _lastIdleCaptureAt;
      if (lastIdleCaptureAt != null &&
          capturedAt.difference(lastIdleCaptureAt) < idleInterval) {
        return;
      }
    }
    if (idle) _lastIdleCaptureAt = capturedAt;

    final windowKey = '${snapshot.appId}|${snapshot.windowTitle}';
    final windowChanged = windowKey != _lastWindowKey;
    if (!windowChanged && !clipboardChanged) return;

    String? visibleText;
    String? screenText;
    String? url;
    if (windowChanged) {
      if (settings.captureVisibleText) {
        visibleText = await _captureSafely(() => captureVisibleText(snapshot));
      }
      if (settings.captureScreenText) {
        captureStatus?.setOcrActive(true);
        try {
          screenText = await _captureSafely(() => captureScreenText(snapshot));
        } finally {
          captureStatus?.setOcrActive(false);
        }
      }
      if (settings.captureBrowserUrls) {
        url = await _captureSafely(() => browserUrlReader(snapshot.appName));
      }
    }

    final finalEnvironment = await readEnvironment();
    captureStatus?.setEnvironment(
      finalEnvironment,
      idle: finalEnvironment.idleFor >= idleThreshold,
    );
    if (finalEnvironment.locked) {
      _clipboardRequiresBaseline = true;
      return;
    }
    final finalSnapshot = readWindow();
    if (finalSnapshot == null || !snapshot.isSameTarget(finalSnapshot)) return;
    final finalSource = await sourceRegistry.observe(finalSnapshot);
    if (!finalSource.canCapture ||
        isExcluded(
          finalSnapshot.appName,
          settings.excludedApps,
          finalSnapshot.appId,
        )) {
      return;
    }

    final storedClipboard = clipboardChanged && clipboard != null
        ? _truncateClipboard(clipboard)
        : null;
    await memory.record(
      NewActivity(
        sourceId: snapshot.appId,
        appName: snapshot.appName,
        windowTitle: snapshot.windowTitle,
        capturedText: visibleText,
        capturedUrl: url,
        capturedClipboard: storedClipboard,
        capturedScreenText: screenText,
        capturedAt: capturedAt,
      ),
    );
    _lastWindowKey = windowKey;
    await sourceRegistry.markCaptured(source.id, capturedAt, {
      if (windowChanged) CaptureModality.metadata,
      if (visibleText != null) CaptureModality.visibleText,
      if (screenText != null) CaptureModality.screenText,
      if (url != null) CaptureModality.browser,
      if (storedClipboard != null) CaptureModality.clipboard,
    });
  }

  static bool isExcluded(
    String appName,
    List<String> excludedApps, [
    String? appId,
  ]) {
    final identities = {
      appName.trim().toLowerCase(),
      if (appId != null) appId.trim().toLowerCase(),
    };
    return excludedApps.any(
      (excluded) => identities.contains(excluded.trim().toLowerCase()),
    );
  }

  Future<String?> _captureSafely(Future<String?> Function() capture) async {
    try {
      return await capture();
    } catch (error, stackTrace) {
      onError(error, stackTrace);
      return null;
    }
  }

  static void _reportError(Object error, StackTrace stackTrace) {
    stderr.writeln('Activity capture tick failed: $error\n$stackTrace');
  }

  static Future<String?> _readClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String _truncateClipboard(String text) =>
      text.length > maxCapturedClipboardLength
          ? text.substring(0, maxCapturedClipboardLength)
          : text;

  static String _hashClipboard(String text) {
    const offset = 0xcbf29ce484222325;
    const prime = 0x100000001b3;
    const mask = 0xffffffffffffffff;
    var hash = offset;
    for (final byte in utf8.encode(text)) {
      hash ^= byte;
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  static Future<String?> _captureVisibleTextViaHelper(WindowSnapshot snapshot) {
    final windowId = snapshot.nativeWindowId;
    if (windowId == null) return Future<String?>.value();
    return _runHelper('uia_capture.exe', uiaHelperTimeout, ['$windowId']);
  }

  static Future<String?> _captureScreenTextViaHelper(WindowSnapshot snapshot) {
    final windowId = snapshot.nativeWindowId;
    if (windowId == null) return Future<String?>.value();
    return _runHelper('screen_ocr.exe', screenOcrTimeout, ['$windowId']);
  }

  static Future<String?> _runHelper(
    String executable,
    Duration timeout,
    List<String> arguments,
  ) async {
    final helperPath = _resolveCompiledHelperPath(executable);
    if (helperPath == null) return null;

    final process = await Process.start(helperPath, arguments);
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();
    final exitCode = await process.exitCode.timeout(
      timeout,
      onTimeout: () {
        process.kill();
        return -1;
      },
    );
    final output = (await stdoutFuture).trim();
    final errorOutput = (await stderrFuture).trim();
    if (exitCode == 1) return null;
    if (exitCode != 0) {
      throw ProcessException(
        helperPath,
        arguments,
        errorOutput.isEmpty ? 'Capture helper failed.' : errorOutput,
        exitCode,
      );
    }
    return output.isEmpty ? null : output;
  }

  static String? _resolveCompiledHelperPath(String executable) {
    if (!Platform.isWindows) return null;
    final helper = p.join(p.dirname(Platform.resolvedExecutable), executable);
    return File(helper).existsSync() ? helper : null;
  }
}
