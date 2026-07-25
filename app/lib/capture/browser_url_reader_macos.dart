import 'dart:io';

const _chromiumBrowsers = {
  'Google Chrome',
  'Microsoft Edge',
  'Brave Browser',
  'Vivaldi',
  'Opera',
};
const _safari = 'Safari';

/// Firefox has no AppleScript scripting dictionary for tab URLs, so it's
/// not supported here — a real gap, not an oversight.
String? readBrowserUrlMacOS(String appName) {
  if (appName == _safari) {
    return _run('tell application "Safari" to get URL of front document');
  }
  if (_chromiumBrowsers.contains(appName)) {
    return _run(
        'tell application "$appName" to get URL of active tab of front window');
  }
  return null;
}

String? _run(String script) {
  try {
    final result = Process.runSync('osascript', ['-e', script]);
    if (result.exitCode != 0) return null;
    final url = (result.stdout as String).trim();
    return url.isEmpty ? null : url;
  } catch (_) {
    return null;
  }
}
