import 'dart:io';

import 'window_snapshot.dart';

const _separator = '|||';

const _frontmostWindowScript = '''
tell application "System Events"
    set frontApp to name of first application process whose frontmost is true
    set winTitle to ""
    try
        set winTitle to name of front window of (first application process whose frontmost is true)
    end try
    return frontApp & "$_separator" & winTitle
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
    final separatorIndex = output.indexOf(_separator);
    if (separatorIndex == -1) return null;

    final appName = output.substring(0, separatorIndex).trim();
    final windowTitle =
        output.substring(separatorIndex + _separator.length).trim();
    if (appName.isEmpty || windowTitle.isEmpty) return null;

    return WindowSnapshot(appName: appName, windowTitle: windowTitle);
  } catch (_) {
    return null;
  }
}
