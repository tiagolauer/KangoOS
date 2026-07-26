import 'package:dbus/dbus.dart';

const _browserKeywords = [
  'chrome',
  'chromium',
  'firefox',
  'brave',
  'edge',
  'vivaldi'
];

const _registryBusName = 'org.a11y.atspi.Registry';
final _registryRootPath = DBusObjectPath('/org/a11y/atspi/accessible/root');
const _accessibleInterface = 'org.a11y.atspi.Accessible';
const _textInterface = 'org.a11y.atspi.Text';

const _atspiStateActive = 1 << 1;
const _skipRoles = {
  'document web',
  'document frame',
  'embedded',
  'internal frame'
};
const _maxDepth = 6;
const _maxNodesVisited = 150;

/// Best-effort: walks the AT-SPI accessibility tree (Linux's screen-reader
/// API) to find the focused browser window's address bar. Requires an
/// AT-SPI-enabled desktop session (GNOME/KDE typically have this on by
/// default; some minimal window managers don't run an AT-SPI bus at all,
/// in which case this silently returns null). Firefox's Linux AT-SPI tree
/// hasn't been verified against this; Chromium-based browsers are the
/// primary target.
Future<String?> readBrowserUrlLinux(String appName) async {
  if (!_browserKeywords
      .any((keyword) => appName.toLowerCase().contains(keyword))) {
    return null;
  }

  DBusClient? sessionClient;
  DBusClient? atspiClient;
  try {
    sessionClient = DBusClient.session();
    final bus = DBusRemoteObject(sessionClient,
        name: 'org.a11y.Bus', path: DBusObjectPath('/org/a11y/bus'));
    final addressResult = await bus.callMethod('org.a11y.Bus', 'GetAddress', [],
        replySignature: DBusSignature('s'));
    final address = addressResult.returnValues[0].asString();

    atspiClient = DBusClient(DBusAddress(address));
    final registry = DBusRemoteObject(atspiClient,
        name: _registryBusName, path: _registryRootPath);
    final apps = await _children(registry);

    for (final app in apps) {
      final appObj = DBusRemoteObject(atspiClient, name: app.$1, path: app.$2);
      final name = await _tryGetName(appObj);
      if (name == null ||
          !_browserKeywords.any((k) => name.toLowerCase().contains(k))) {
        continue;
      }

      final url = await _findActiveAddressBarUrl(atspiClient, appObj);
      if (url != null) return url;
    }
    return null;
  } catch (_) {
    return null;
  } finally {
    await sessionClient?.close();
    await atspiClient?.close();
  }
}

Future<String?> _findActiveAddressBarUrl(
    DBusClient client, DBusRemoteObject appObj) async {
  for (final frame in await _children(appObj)) {
    final frameObj = DBusRemoteObject(client, name: frame.$1, path: frame.$2);
    if (await _isActive(frameObj)) {
      return _searchForAddressBar(client, frameObj, depth: 0, visited: [0]);
    }
  }
  return null;
}

Future<bool> _isActive(DBusRemoteObject node) async {
  try {
    final result = await node.callMethod(_accessibleInterface, 'GetState', [],
        replySignature: DBusSignature('au'));
    final states =
        result.returnValues[0].asArray().map((v) => v.asUint32()).toList();
    return states.isNotEmpty && (states[0] & _atspiStateActive) != 0;
  } catch (_) {
    return false;
  }
}

Future<String?> _searchForAddressBar(
  DBusClient client,
  DBusRemoteObject node, {
  required int depth,
  required List<int> visited,
}) async {
  if (depth > _maxDepth || visited[0] > _maxNodesVisited) return null;
  visited[0]++;

  final role = await _tryGetRoleName(node);
  if (role == 'entry') {
    final text = await _entryText(node);
    if (text != null && _looksLikeUrl(text)) return text;
  }
  if (role != null && _skipRoles.contains(role)) return null;

  for (final child in await _children(node)) {
    final childObj = DBusRemoteObject(client, name: child.$1, path: child.$2);
    final found = await _searchForAddressBar(client, childObj,
        depth: depth + 1, visited: visited);
    if (found != null) return found;
  }
  return null;
}

Future<List<(String, DBusObjectPath)>> _children(DBusRemoteObject node) async {
  try {
    final result = await node.callMethod(
        _accessibleInterface, 'GetChildren', [],
        replySignature: DBusSignature('a(so)'));
    return result.returnValues[0]
        .asArray()
        .map((child) => child.asStruct())
        .map((child) => (child[0].asString(), child[1].asObjectPath()))
        .toList();
  } catch (_) {
    return const [];
  }
}

Future<String?> _tryGetName(DBusRemoteObject node) async {
  try {
    return (await node.getProperty(_accessibleInterface, 'Name')).asString();
  } catch (_) {
    return null;
  }
}

Future<String?> _tryGetRoleName(DBusRemoteObject node) async {
  try {
    final result = await node.callMethod(
        _accessibleInterface, 'GetRoleName', [],
        replySignature: DBusSignature('s'));
    return result.returnValues[0].asString();
  } catch (_) {
    return null;
  }
}

Future<String?> _entryText(DBusRemoteObject node) async {
  try {
    final result = await node.callMethod(
      _textInterface,
      'GetText',
      [const DBusInt32(0), const DBusInt32(-1)],
      replySignature: DBusSignature('s'),
    );
    return result.returnValues[0].asString();
  } catch (_) {
    return null;
  }
}

final _urlLike = RegExp(r'^([a-zA-Z][a-zA-Z\d+.-]*://|[\w-]+\.[a-z]{2,})');

bool _looksLikeUrl(String value) => _urlLike.hasMatch(value.trim());
