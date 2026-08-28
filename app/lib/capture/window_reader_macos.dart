import 'dart:io';

import 'window_snapshot.dart';

const _separator = '|||';

const _frontmostWindowScript = '''
tell application "System Events"
    set frontApp to name of first application process whose frontmost is true
    set frontBundle to bundle identifier of first application process whose frontmost is true
    set winTitle to ""
    try
        set winTitle to name of front window of (first application process whose frontmost is true)
    end try
    return frontApp & "$_separator" & frontBundle & "$_separator" & winTitle
end tell
''';

/// Requires the app to be granted Accessibility permission (System Settings ->
/// Privacy & Security -> Accessibility) so "System Events" can read other
/// apps' window titles; otherwise the window title comes back empty.
WindowSnapshot? readForegroundWindowMacOS() {
  try {
    final result = Process.runSync('osascript', ['-e', _frontmostWindowScript]);
    if (result.exitCode != 0) return null;

    final output = (result.stdout as String).trim();
    final parts = output.split(_separator);
    if (parts.length != 3) return null;

    final appName = parts[0].trim();
    final bundleId = parts[1].trim();
    final windowTitle = parts[2].trim();
    if (appName.isEmpty || bundleId.isEmpty || windowTitle.isEmpty) return null;

    return WindowSnapshot(
      appId: 'macos:$bundleId',
      appName: appName,
      windowTitle: windowTitle,
    );
  } catch (_) {
    return null;
  }
}
