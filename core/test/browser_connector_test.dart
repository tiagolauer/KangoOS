import 'dart:convert';
import 'dart:io';

import 'package:kangoos_core/src/connectors/agent_connector.dart';
import 'package:kangoos_core/src/connectors/browser_connector.dart';
import 'package:kangoos_core/src/llm/llm_stream.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Directory sandbox;
  late Directory chromium;
  late Directory firefox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp(
      'kangoos-browser-connector-',
    );
    chromium =
        await Directory(
          '${sandbox.path}${Platform.pathSeparator}chromium',
        ).create();
    firefox =
        await Directory(
          '${sandbox.path}${Platform.pathSeparator}firefox',
        ).create();
    _createChromiumData(chromium);
    _createFirefoxData(firefox);
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test(
    'searches Chromium and Firefox history and bookmarks with evidence',
    () async {
      final connector = BrowserConnector(
        profilesProvider: () async => _profiles(chromium, firefox),
      );

      final result = await AgentConnectorRegistry(connector.tools).execute(
        searchBrowserToolName,
        {'query': 'kango', 'source': 'all', 'limit': 20},
        _context(),
      );

      final matches = _browserMatches(result);
      expect(matches, hasLength(4));
      expect(matches.map((match) => match['source']).toSet(), {
        'history',
        'bookmarks',
      });
      expect(matches.map((match) => match['profileId']).toSet(), {
        'chromium',
        'firefox',
      });
      expect(result.evidence, hasLength(4));
      expect(
        result.evidence.every(
          (evidence) =>
              evidence.kind == ConnectorEvidenceKind.browser &&
              evidence.content.contains('URL: https://kango.local/') &&
              evidence.toJson()['untrusted'] == true,
        ),
        isTrue,
      );
      expect(
        matches.map((match) => match['evidenceId']).toSet(),
        result.evidence.map((evidence) => evidence.id).toSet(),
      );
    },
  );

  test(
    'restricts search to explicitly selected profiles and sources',
    () async {
      final registry = AgentConnectorRegistry(
        BrowserConnector(
          profilesProvider: () async => _profiles(chromium, firefox),
        ).tools,
      );

      final result = await registry.execute(searchBrowserToolName, {
        'query': 'kango',
        'profileIds': ['chromium'],
        'source': 'bookmarks',
      }, _context());

      expect(_browserMatches(result), hasLength(1));
      expect(_browserMatches(result).single['profileId'], 'chromium');
      expect(_browserMatches(result).single['source'], 'bookmarks');
      await expectLater(
        registry.execute(searchBrowserToolName, {
          'query': 'kango',
          'profileIds': ['not-allowed'],
        }, _context()),
        throwsA(isA<BrowserAccessException>()),
      );
    },
  );

  test('does not discover profiles outside the provider allowlist', () async {
    final connector = BrowserConnector(
      profilesProvider:
          () async => [
            BrowserProfile(
              id: 'chromium',
              name: 'Chromium',
              kind: BrowserProfileKind.chromium,
              path: chromium.path,
            ),
          ],
    );

    final result = await AgentConnectorRegistry(connector.tools).execute(
      searchBrowserToolName,
      {'query': 'kango', 'limit': 20},
      _context(),
    );

    expect(_browserMatches(result).map((match) => match['profileId']).toSet(), {
      'chromium',
    });
  });

  test('escapes SQL wildcard characters in the history query', () async {
    final connector = BrowserConnector(
      profilesProvider:
          () async => [
            BrowserProfile(
              id: 'chromium',
              name: 'Chromium',
              kind: BrowserProfileKind.chromium,
              path: chromium.path,
            ),
          ],
    );

    final result = await AgentConnectorRegistry(connector.tools).execute(
      searchBrowserToolName,
      {'query': '%', 'source': 'history'},
      _context(),
    );

    expect(_browserMatches(result), hasLength(1));
    expect(_browserMatches(result).single['title'], 'Literal 100%');
  });

  test('rejects browser data symlinks that escape the profile', () async {
    final external = File(
      '${sandbox.path}${Platform.pathSeparator}external-history',
    );
    _createChromiumHistory(external);
    final linkedProfile =
        await Directory(
          '${sandbox.path}${Platform.pathSeparator}linked-profile',
        ).create();
    final link = Link('${linkedProfile.path}${Platform.pathSeparator}History');
    try {
      await link.create(external.path);
    } on FileSystemException {
      markTestSkipped('This host does not permit creating symbolic links.');
      return;
    }
    final connector = BrowserConnector(
      profilesProvider:
          () async => [
            BrowserProfile(
              id: 'linked',
              name: 'Linked',
              kind: BrowserProfileKind.chromium,
              path: linkedProfile.path,
            ),
          ],
    );

    await expectLater(
      AgentConnectorRegistry(connector.tools).execute(searchBrowserToolName, {
        'query': 'kango',
        'source': 'history',
      }, _context()),
      throwsA(isA<BrowserAccessException>()),
    );
  });

  test('removes results when an allowed profile is revoked', () async {
    var providerCalls = 0;
    final connector = BrowserConnector(
      profilesProvider:
          () async =>
              providerCalls++ == 0 ? _profiles(chromium, firefox) : const [],
    );

    final result = await AgentConnectorRegistry(
      connector.tools,
    ).execute(searchBrowserToolName, {'query': 'kango'}, _context());

    expect(_browserMatches(result), isEmpty);
    expect(result.evidence, isEmpty);
  });

  test('honors cancellation before reading a profile', () async {
    final cancelToken = CancelToken();
    final connector = BrowserConnector(
      profilesProvider: () async {
        cancelToken.cancel();
        return _profiles(chromium, firefox);
      },
    );

    await expectLater(
      AgentConnectorRegistry(connector.tools).execute(searchBrowserToolName, {
        'query': 'kango',
      }, _context(cancelToken: cancelToken)),
      throwsA(isA<ConnectorCancelledException>()),
    );
  });
}

List<BrowserProfile> _profiles(Directory chromium, Directory firefox) => [
  BrowserProfile(
    id: 'chromium',
    name: 'Chromium Test',
    kind: BrowserProfileKind.chromium,
    path: chromium.path,
  ),
  BrowserProfile(
    id: 'firefox',
    name: 'Firefox Test',
    kind: BrowserProfileKind.firefox,
    path: firefox.path,
  ),
];

ConnectorRunContext _context({CancelToken? cancelToken}) => ConnectorRunContext(
  surface: ConnectorSurface.desktop,
  deadline: DateTime.now().add(const Duration(minutes: 1)),
  cancelToken: cancelToken,
  permissionChecker: (_, _, _, _) async => true,
);

List<Map<String, Object?>> _browserMatches(ConnectorToolResult result) =>
    ((result.data! as Map<String, Object?>)['matches']! as List<Object?>)
        .cast<Map<String, Object?>>();

void _createChromiumData(Directory profile) {
  _createChromiumHistory(
    File('${profile.path}${Platform.pathSeparator}History'),
  );
  final webkitDate = _webkitMicroseconds(DateTime.utc(2026, 8, 26, 12));
  File('${profile.path}${Platform.pathSeparator}Bookmarks').writeAsStringSync(
    jsonEncode({
      'roots': {
        'bookmark_bar': {
          'type': 'folder',
          'children': [
            {
              'type': 'url',
              'name': 'Kango Bookmark',
              'url': 'https://kango.local/chromium-bookmark',
              'date_added': webkitDate.toString(),
            },
            {
              'type': 'url',
              'name': 'Unrelated Bookmark',
              'url': 'https://unrelated.local/bookmark',
              'date_added': webkitDate.toString(),
            },
          ],
        },
      },
    }),
  );
}

void _createChromiumHistory(File file) {
  final database = sqlite3.open(file.path);
  try {
    database.execute('''
CREATE TABLE urls (
  id INTEGER PRIMARY KEY,
  url TEXT NOT NULL,
  title TEXT
);
CREATE TABLE visits (
  id INTEGER PRIMARY KEY,
  url INTEGER NOT NULL,
  visit_time INTEGER
);
''');
    database.execute('INSERT INTO urls (id, url, title) VALUES (?, ?, ?)', [
      1,
      'https://kango.local/chromium-history',
      'Kango History',
    ]);
    database.execute('INSERT INTO urls (id, url, title) VALUES (?, ?, ?)', [
      2,
      'https://example.local/percent',
      'Literal 100%',
    ]);
    database.execute('INSERT INTO urls (id, url, title) VALUES (?, ?, ?)', [
      3,
      'https://unrelated.local/history',
      'Unrelated History',
    ]);
    final visitedAt = _webkitMicroseconds(DateTime.utc(2026, 8, 26, 10));
    for (final id in [1, 2, 3]) {
      database.execute(
        'INSERT INTO visits (id, url, visit_time) VALUES (?, ?, ?)',
        [id, id, visitedAt + id],
      );
    }
  } finally {
    database.dispose();
  }
}

void _createFirefoxData(Directory profile) {
  final database = sqlite3.open(
    '${profile.path}${Platform.pathSeparator}places.sqlite',
  );
  try {
    database.execute('''
CREATE TABLE moz_places (
  id INTEGER PRIMARY KEY,
  url TEXT NOT NULL,
  title TEXT
);
CREATE TABLE moz_historyvisits (
  id INTEGER PRIMARY KEY,
  place_id INTEGER NOT NULL,
  visit_date INTEGER
);
CREATE TABLE moz_bookmarks (
  id INTEGER PRIMARY KEY,
  fk INTEGER,
  type INTEGER NOT NULL,
  title TEXT,
  dateAdded INTEGER
);
''');
    database.execute(
      'INSERT INTO moz_places (id, url, title) VALUES (?, ?, ?)',
      [1, 'https://kango.local/firefox-history', 'Kango Firefox History'],
    );
    database.execute(
      'INSERT INTO moz_places (id, url, title) VALUES (?, ?, ?)',
      [2, 'https://kango.local/firefox-bookmark', 'Fallback Title'],
    );
    database.execute(
      'INSERT INTO moz_historyvisits (id, place_id, visit_date) '
      'VALUES (?, ?, ?)',
      [1, 1, DateTime.utc(2026, 8, 26, 11).microsecondsSinceEpoch],
    );
    database.execute(
      'INSERT INTO moz_bookmarks (id, fk, type, title, dateAdded) '
      'VALUES (?, ?, ?, ?, ?)',
      [
        1,
        2,
        1,
        'Kango Firefox Bookmark',
        DateTime.utc(2026, 8, 26, 13).microsecondsSinceEpoch,
      ],
    );
  } finally {
    database.dispose();
  }
}

int _webkitMicroseconds(DateTime date) {
  const windowsToUnixEpochMicroseconds = 11644473600000000;
  return date.toUtc().microsecondsSinceEpoch + windowsToUnixEpochMicroseconds;
}
