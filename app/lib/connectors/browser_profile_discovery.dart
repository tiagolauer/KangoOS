import 'dart:convert';
import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:path/path.dart' as p;

class BrowserProfileDiscovery {
  Future<List<BrowserProfile>> discover() async {
    final profiles = <BrowserProfile>[];
    for (final root in _chromiumRoots()) {
      final directory = Directory(root.path);
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! Directory) continue;
        final hasHistory = await File(p.join(entity.path, 'History')).exists();
        final hasBookmarks =
            await File(p.join(entity.path, 'Bookmarks')).exists();
        if (!hasHistory && !hasBookmarks) continue;
        profiles.add(
          BrowserProfile(
            id: _profileId(root.name, entity.path),
            name: '${root.name} · ${p.basename(entity.path)}',
            kind: BrowserProfileKind.chromium,
            path: entity.path,
          ),
        );
      }
    }
    for (final root in _firefoxRoots()) {
      final directory = Directory(root);
      if (!await directory.exists()) continue;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! Directory ||
            !await File(p.join(entity.path, 'places.sqlite')).exists()) {
          continue;
        }
        profiles.add(
          BrowserProfile(
            id: _profileId('firefox', entity.path),
            name: 'Firefox · ${p.basename(entity.path)}',
            kind: BrowserProfileKind.firefox,
            path: entity.path,
          ),
        );
      }
    }
    profiles.sort((left, right) => left.name.compareTo(right.name));
    return profiles;
  }

  static String encode(BrowserProfile profile) => jsonEncode({
    'name': profile.name,
    'kind': profile.kind.name,
    'path': profile.path,
  });

  static BrowserProfile decode(String id, String location) {
    final value = jsonDecode(location);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Perfil de navegador inválido.');
    }
    final name = value['name'];
    final path = value['path'];
    final kindName = value['kind'];
    if (name is! String || path is! String || kindName is! String) {
      throw const FormatException('Perfil de navegador incompleto.');
    }
    final kind = BrowserProfileKind.values.firstWhere(
      (candidate) => candidate.name == kindName,
      orElse:
          () =>
              throw const FormatException(
                'Tipo de perfil de navegador inválido.',
              ),
    );
    return BrowserProfile(id: id, name: name, kind: kind, path: path);
  }

  List<_BrowserRoot> _chromiumRoots() {
    final env = Platform.environment;
    final home = env['USERPROFILE'] ?? env['HOME'];
    if (Platform.isWindows) {
      final local = env['LOCALAPPDATA'];
      if (local == null) return const [];
      return [
        _BrowserRoot('Chrome', p.join(local, 'Google', 'Chrome', 'User Data')),
        _BrowserRoot('Edge', p.join(local, 'Microsoft', 'Edge', 'User Data')),
        _BrowserRoot(
          'Brave',
          p.join(local, 'BraveSoftware', 'Brave-Browser', 'User Data'),
        ),
      ];
    }
    if (home == null) return const [];
    if (Platform.isMacOS) {
      final support = p.join(home, 'Library', 'Application Support');
      return [
        _BrowserRoot('Chrome', p.join(support, 'Google', 'Chrome')),
        _BrowserRoot('Edge', p.join(support, 'Microsoft Edge')),
        _BrowserRoot(
          'Brave',
          p.join(support, 'BraveSoftware', 'Brave-Browser'),
        ),
      ];
    }
    final config = p.join(home, '.config');
    return [
      _BrowserRoot('Chrome', p.join(config, 'google-chrome')),
      _BrowserRoot('Chromium', p.join(config, 'chromium')),
      _BrowserRoot('Edge', p.join(config, 'microsoft-edge')),
      _BrowserRoot('Brave', p.join(config, 'BraveSoftware', 'Brave-Browser')),
    ];
  }

  List<String> _firefoxRoots() {
    final env = Platform.environment;
    final home = env['USERPROFILE'] ?? env['HOME'];
    if (Platform.isWindows) {
      final roaming = env['APPDATA'];
      return roaming == null
          ? const []
          : [p.join(roaming, 'Mozilla', 'Firefox', 'Profiles')];
    }
    if (home == null) return const [];
    return [
      Platform.isMacOS
          ? p.join(
            home,
            'Library',
            'Application Support',
            'Firefox',
            'Profiles',
          )
          : p.join(home, '.mozilla', 'firefox'),
    ];
  }
}

class _BrowserRoot {
  const _BrowserRoot(this.name, this.path);

  final String name;
  final String path;
}

String _profileId(String browser, String path) {
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode('${browser.toLowerCase()}:$path')) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
  }
  return 'browser:${hash.toRadixString(16)}';
}
