import 'package:kangoos_core/src/cli/kango_paths.dart';
import 'package:test/test.dart';

void main() {
  test('defaultDbPath uses APPDATA on Windows', () {
    final path = defaultDbPath(
      environment: {'APPDATA': r'C:\Users\alaska\AppData\Roaming'},
      operatingSystem: 'windows',
    );
    expect(path, r'C:\Users\alaska\AppData\Roaming\KangoOS\kangoos.db');
  });

  test('defaultDbPath uses Library/Application Support on macOS', () {
    final path = defaultDbPath(
      environment: {'HOME': '/Users/alaska'},
      operatingSystem: 'macos',
    );
    expect(
        path, '/Users/alaska/Library/Application Support/KangoOS/kangoos.db');
  });

  test('defaultDbPath respects XDG_DATA_HOME on Linux', () {
    final path = defaultDbPath(
      environment: {
        'XDG_DATA_HOME': '/home/alaska/.data',
        'HOME': '/home/alaska'
      },
      operatingSystem: 'linux',
    );
    expect(path, '/home/alaska/.data/KangoOS/kangoos.db');
  });

  test(
      'defaultDbPath falls back to HOME/.local/share on Linux without XDG_DATA_HOME',
      () {
    final path = defaultDbPath(
      environment: {'HOME': '/home/alaska'},
      operatingSystem: 'linux',
    );
    expect(path, '/home/alaska/.local/share/KangoOS/kangoos.db');
  });
}
