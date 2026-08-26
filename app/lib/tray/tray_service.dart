import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../capture/capture_settings_repository.dart';
import '../runtime/runtime_service.dart';

class TrayService with TrayListener, WindowListener implements RuntimeService {
  TrayService({
    required this.captureSettingsRepository,
    this.onSaveClipboardAsSnippet,
    this.onQuit,
  });

  final CaptureSettingsRepository captureSettingsRepository;

  final Future<int?> Function()? onSaveClipboardAsSnippet;
  final Future<void> Function()? onQuit;
  final _panelVisible = ValueNotifier(false);

  Rect? _mainWindowBounds;
  var _mainWindowWasMaximized = false;
  var _showingPanel = false;
  var _changingWindowMode = false;

  static const _panelSize = Size(380, 560);
  static const _panelMargin = Offset(12, 12);
  static const _windowChannel = MethodChannel('kangoos/window');

  static bool get isSupported => Platform.isWindows;
  ValueListenable<bool> get panelVisible => _panelVisible;

  Future<void> init() async {
    if (!isSupported) return;

    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow();
    await windowManager.setPreventClose(true);
    await _windowChannel.invokeMethod<void>('setCloseToTray', true);
    windowManager.addListener(this);

    trayManager.addListener(this);
    await trayManager.setIcon('assets/tray_icon.ico');
    await trayManager.setToolTip('KangoOS');
  }

  @override
  Future<void> start() => init();

  void dispose() {
    if (!isSupported) return;
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    _panelVisible.dispose();
  }

  @override
  Future<void> stop() async => dispose();

  Future<void> showMainWindow() async {
    if (_changingWindowMode) return;
    if (!_showingPanel) {
      await windowManager.show();
      await windowManager.focus();
      return;
    }

    _changingWindowMode = true;
    try {
      await windowManager.hide();
      _showingPanel = false;
      _panelVisible.value = false;
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setSkipTaskbar(false);
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setResizable(true);
      if (_mainWindowBounds case final bounds?) {
        await windowManager.setBounds(bounds);
      }
      await windowManager.show();
      if (_mainWindowWasMaximized) await windowManager.maximize();
      await windowManager.focus();
    } finally {
      _changingWindowMode = false;
    }
  }

  Future<void> showTrayPanel() async {
    if (_changingWindowMode) return;
    if (_showingPanel) {
      await windowManager.show();
      await windowManager.focus();
      return;
    }

    _changingWindowMode = true;
    try {
      _mainWindowBounds = await windowManager.getBounds();
      _mainWindowWasMaximized = await windowManager.isMaximized();
      if (_mainWindowWasMaximized) await windowManager.unmaximize();
      await windowManager.hide();
      _showingPanel = true;
      _panelVisible.value = true;
      await windowManager.setTitleBarStyle(
        TitleBarStyle.hidden,
        windowButtonVisibility: false,
      );
      await windowManager.setSkipTaskbar(true);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setResizable(false);
      await windowManager.setSize(_panelSize);
      await windowManager.setAlignment(Alignment.bottomRight);
      final bounds = await windowManager.getBounds();
      await windowManager.setPosition(bounds.topLeft - _panelMargin);
      await windowManager.show();
      await windowManager.focus();
    } finally {
      _changingWindowMode = false;
    }
  }

  Future<void> hideTrayPanel() async {
    if (_showingPanel) await windowManager.hide();
  }

  Future<void> toggleCapture() async {
    final current = await captureSettingsRepository.load();
    await captureSettingsRepository.save(
      current.copyWith(paused: !current.paused, clearResumeAt: true),
    );
  }

  Future<bool> saveClipboardAsSnippet() async {
    final save = onSaveClipboardAsSnippet;
    return save != null && await save() != null;
  }

  Future<void> quit() async {
    await _windowChannel.invokeMethod<void>('setCloseToTray', false);
    await onQuit?.call();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onTrayIconMouseDown() => unawaited(showMainWindow());

  @override
  void onTrayIconRightMouseDown() => unawaited(showTrayPanel());

  @override
  void onWindowClose() => unawaited(_hideOnClose());

  Future<void> _hideOnClose() async {
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }

  @override
  void onWindowBlur() {
    if (_showingPanel && !_changingWindowMode) {
      unawaited(_hidePanelAfterBlur());
    }
  }

  Future<void> _hidePanelAfterBlur() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (_showingPanel &&
        !_changingWindowMode &&
        !await windowManager.isFocused()) {
      await windowManager.hide();
    }
  }
}
