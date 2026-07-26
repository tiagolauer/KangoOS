import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../capture/capture_settings_repository.dart';

class TrayService with TrayListener, WindowListener {
  TrayService({required this.captureSettingsRepository});

  final CaptureSettingsRepository captureSettingsRepository;

  static bool get isSupported => Platform.isWindows;

  Future<void> init() async {
    if (!isSupported) return;

    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    trayManager.addListener(this);
    await trayManager.setIcon('assets/tray_icon.ico');
    await trayManager.setToolTip('KangoOS');
  }

  void dispose() {
    if (!isSupported) return;
    windowManager.removeListener(this);
    trayManager.removeListener(this);
  }

  Future<void> refreshMenu() async {
    if (!isSupported) return;
    final settings = await captureSettingsRepository.load();
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Show KangoOS', onClick: (_) => _show()),
      MenuItem.separator(),
      MenuItem(
        key: 'toggle_pause',
        label: settings.paused ? 'Resume capture' : 'Pause capture',
        onClick: (_) => _togglePause(settings),
      ),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit', onClick: (_) => _quit()),
    ]));
  }

  Future<void> _show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _togglePause(CaptureSettings current) async {
    await captureSettingsRepository
        .save(current.copyWith(paused: !current.paused));
    await refreshMenu();
  }

  Future<void> _quit() async {
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onTrayIconMouseDown() => _show();

  @override
  void onTrayIconRightMouseDown() async {
    await refreshMenu();
    await trayManager.popUpContextMenu();
  }

  @override
  void onWindowClose() async {
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }
}
