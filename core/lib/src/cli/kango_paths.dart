import 'dart:io';

import 'package:path/path.dart' as p;

/// Default location for the CLI's own database file.
///
/// This is deliberately NOT the same file the Flutter desktop app uses —
/// replicating Flutter's `path_provider` folder resolution (which reads the
/// app's CompanyName/ProductName from native OS metadata) from a plain Dart
/// CLI would be fragile and silently wrong if that metadata ever changes.
/// Point the `KANGOOS_DB_PATH` env var at the app's db file to share storage
/// instead.
String defaultDbPath(
    {Map<String, String>? environment, String? operatingSystem}) {
  final env = environment ?? Platform.environment;
  final os = operatingSystem ?? Platform.operatingSystem;
  // Uses an explicit Context (not the top-level p.join) so the separator
  // matches the target [os] rather than whatever host this code runs on.
  final ctx =
      p.Context(style: os == 'windows' ? p.Style.windows : p.Style.posix);

  final String base;
  switch (os) {
    case 'windows':
      base = env['APPDATA'] ??
          ctx.join(env['USERPROFILE'] ?? '.', 'AppData', 'Roaming');
    case 'macos':
      base = ctx.join(env['HOME'] ?? '.', 'Library', 'Application Support');
    default:
      base = env['XDG_DATA_HOME'] ??
          ctx.join(env['HOME'] ?? '.', '.local', 'share');
  }

  return ctx.join(base, 'KangoOS', 'kangoos.db');
}
