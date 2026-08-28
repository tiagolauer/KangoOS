import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../llm/llm_provider.dart';
import 'agent_connector.dart';

const searchBrowserToolName = 'search_browser';
const maxBrowserSearchResults = 20;
const browserRevalidationInterval = 64;

enum BrowserProfileKind { chromium, firefox }

enum BrowserSearchSource { history, bookmarks, all }

class BrowserProfile {
  const BrowserProfile({
    required this.id,
    required this.name,
    required this.kind,
    required this.path,
  });

  final String id;
  final String name;
  final BrowserProfileKind kind;
  final String path;
}

typedef BrowserProfilesProvider = Future<List<BrowserProfile>> Function();

class BrowserConnector {
  BrowserConnector({required this.profilesProvider}) {
    tools = [_SearchBrowserTool(this)];
  }

  final BrowserProfilesProvider profilesProvider;
  late final List<AgentConnectorTool> tools;

  Future<ConnectorToolResult> search(
    Map<String, Object?> arguments,
    ConnectorRunContext context,
  ) async {
    final query = _requiredBrowserString(arguments, 'query');
    final source = _browserSource(arguments['source']);
    final limit = _browserLimit(arguments['limit']);
    final requestedProfileIds = _browserStrings(arguments['profileIds']);
    var allowedProfiles = await _loadProfiles();
    final profiles =
        requestedProfileIds.isEmpty
            ? allowedProfiles.values.toList(growable: false)
            : requestedProfileIds
                .map((id) {
                  final profile = allowedProfiles[id];
                  if (profile == null) {
                    throw BrowserAccessException(
                      'Browser profile not allowed: $id',
                    );
                  }
                  return profile;
                })
                .toList(growable: false);
    final matches = <_BrowserMatch>[];

    for (final profile in profiles) {
      await context.guard(searchBrowserToolName, ConnectorAccess.read);
      allowedProfiles = await _loadProfiles();
      if (!_sameProfile(allowedProfiles[profile.source.id], profile)) continue;
      switch (profile.source.kind) {
        case BrowserProfileKind.chromium:
          matches.addAll(
            await _searchChromium(profile, query, source, limit, context),
          );
        case BrowserProfileKind.firefox:
          matches.addAll(
            await _searchFirefox(profile, query, source, limit, context),
          );
      }
    }

    matches.sort(_newestFirst);
    await context.guard(searchBrowserToolName, ConnectorAccess.read);
    allowedProfiles = await _loadProfiles();
    final visible = matches
        .where(
          (match) => _sameProfile(
            allowedProfiles[match.profile.source.id],
            match.profile,
          ),
        )
        .take(limit)
        .toList(growable: false);
    return ConnectorToolResult(
      data: {'matches': visible.map((match) => match.toJson()).toList()},
      evidence: visible.map((match) => match.evidence).toList(growable: false),
    );
  }

  Future<List<_BrowserMatch>> _searchChromium(
    _AllowedBrowserProfile profile,
    String query,
    BrowserSearchSource source,
    int limit,
    ConnectorRunContext context,
  ) async {
    final matches = <_BrowserMatch>[];
    if (source != BrowserSearchSource.bookmarks) {
      final history = await _profileFile(profile, 'History');
      if (history != null) {
        matches.addAll(
          _queryDatabase(
            profile: profile,
            file: history,
            source: BrowserSearchSource.history,
            query: query,
            limit: limit,
            sql: '''
SELECT u.url AS url,
       COALESCE(u.title, '') AS title,
       MAX(v.visit_time) AS occurred_at
FROM urls AS u
JOIN visits AS v ON v.url = u.id
WHERE lower(u.url) LIKE ? ESCAPE '\\'
   OR lower(COALESCE(u.title, '')) LIKE ? ESCAPE '\\'
GROUP BY u.id
ORDER BY occurred_at DESC
LIMIT ?
''',
            dateParser: _chromiumDate,
          ),
        );
      }
    }
    if (source != BrowserSearchSource.history) {
      await context.guard(searchBrowserToolName, ConnectorAccess.read);
      final bookmarks = await _profileFile(profile, 'Bookmarks');
      if (bookmarks != null) {
        matches.addAll(
          await _searchChromiumBookmarks(
            profile,
            bookmarks,
            query,
            source == BrowserSearchSource.all ? limit : limit - matches.length,
            context,
          ),
        );
      }
    }
    return matches;
  }

  Future<List<_BrowserMatch>> _searchFirefox(
    _AllowedBrowserProfile profile,
    String query,
    BrowserSearchSource source,
    int limit,
    ConnectorRunContext context,
  ) async {
    final places = await _profileFile(profile, 'places.sqlite');
    if (places == null) return const [];
    final matches = <_BrowserMatch>[];
    if (source != BrowserSearchSource.bookmarks) {
      matches.addAll(
        _queryDatabase(
          profile: profile,
          file: places,
          source: BrowserSearchSource.history,
          query: query,
          limit: limit,
          sql: '''
SELECT p.url AS url,
       COALESCE(p.title, '') AS title,
       MAX(v.visit_date) AS occurred_at
FROM moz_places AS p
JOIN moz_historyvisits AS v ON v.place_id = p.id
WHERE lower(p.url) LIKE ? ESCAPE '\\'
   OR lower(COALESCE(p.title, '')) LIKE ? ESCAPE '\\'
GROUP BY p.id
ORDER BY occurred_at DESC
LIMIT ?
''',
          dateParser: _unixMicrosecondsDate,
        ),
      );
    }
    if (source != BrowserSearchSource.history) {
      await context.guard(searchBrowserToolName, ConnectorAccess.read);
      matches.addAll(
        _queryDatabase(
          profile: profile,
          file: places,
          source: BrowserSearchSource.bookmarks,
          query: query,
          limit:
              source == BrowserSearchSource.all
                  ? limit
                  : limit - matches.length,
          sql: '''
SELECT p.url AS url,
       COALESCE(b.title, p.title, '') AS title,
       b.dateAdded AS occurred_at
FROM moz_bookmarks AS b
JOIN moz_places AS p ON p.id = b.fk
WHERE b.type = 1
  AND (lower(p.url) LIKE ? ESCAPE '\\'
       OR lower(COALESCE(b.title, p.title, '')) LIKE ? ESCAPE '\\')
ORDER BY occurred_at DESC
LIMIT ?
''',
          dateParser: _unixMicrosecondsDate,
        ),
      );
    }
    return matches;
  }

  List<_BrowserMatch> _queryDatabase({
    required _AllowedBrowserProfile profile,
    required File file,
    required BrowserSearchSource source,
    required String query,
    required int limit,
    required String sql,
    required DateTime? Function(Object? value) dateParser,
  }) {
    Database? database;
    try {
      database = sqlite3.open(file.path, mode: OpenMode.readOnly);
      final pattern = _likePattern(query);
      final rows = database.select(sql, [pattern, pattern, limit]);
      return rows
          .map(
            (row) => _browserMatch(
              profile: profile,
              source: source,
              url: row['url'] as String,
              title: row['title'] as String,
              occurredAt: dateParser(row['occurred_at']),
            ),
          )
          .toList(growable: false);
    } on SqliteException catch (error) {
      throw BrowserAccessException(
        'Could not read ${source.name} for ${profile.source.id}: '
        '${error.message}',
      );
    } finally {
      database?.dispose();
    }
  }

  Future<List<_BrowserMatch>> _searchChromiumBookmarks(
    _AllowedBrowserProfile profile,
    File file,
    String query,
    int limit,
    ConnectorRunContext context,
  ) async {
    Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString(encoding: utf8));
    } on FileSystemException catch (error) {
      throw BrowserAccessException(
        'Could not read bookmarks for ${profile.source.id}: ${error.message}',
      );
    } on FormatException catch (error) {
      throw BrowserAccessException(
        'Invalid bookmarks for ${profile.source.id}: ${error.message}',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw BrowserAccessException(
        'Invalid bookmarks for ${profile.source.id}: expected an object',
      );
    }
    final roots = decoded['roots'];
    if (roots is! Map<String, Object?>) return const [];
    final pending = <Object?>[...roots.values];
    final matches = <_BrowserMatch>[];
    var visited = 0;
    while (pending.isNotEmpty && matches.length < limit) {
      if (visited++ % browserRevalidationInterval == 0) {
        await context.guard(searchBrowserToolName, ConnectorAccess.read);
        final current = (await _loadProfiles())[profile.source.id];
        if (!_sameProfile(current, profile)) return const [];
      }
      final node = pending.removeLast();
      if (node is! Map<String, Object?>) continue;
      final children = node['children'];
      if (children is List) pending.addAll(children);
      if (node['type'] != 'url') continue;
      final url = node['url'];
      if (url is! String || url.isEmpty) continue;
      final title = node['name'] is String ? node['name'] as String : '';
      if (!_containsIgnoreCase(url, query) &&
          !_containsIgnoreCase(title, query)) {
        continue;
      }
      matches.add(
        _browserMatch(
          profile: profile,
          source: BrowserSearchSource.bookmarks,
          url: url,
          title: title,
          occurredAt: _chromiumDate(node['date_added']),
        ),
      );
    }
    return matches;
  }

  Future<Map<String, _AllowedBrowserProfile>> _loadProfiles() async {
    final allowed = <String, _AllowedBrowserProfile>{};
    for (final profile in await profilesProvider()) {
      final id = profile.id.trim();
      if (id.isEmpty) {
        throw const FormatException('Browser profile id cannot be empty');
      }
      if (allowed.containsKey(id)) {
        throw FormatException('Duplicate browser profile id: $id');
      }
      final type = await FileSystemEntity.type(
        profile.path,
        followLinks: false,
      );
      if (type != FileSystemEntityType.directory) continue;
      final canonical = await Directory(profile.path).resolveSymbolicLinks();
      allowed[id] = _AllowedBrowserProfile(
        source: BrowserProfile(
          id: id,
          name: profile.name.trim().isEmpty ? id : profile.name.trim(),
          kind: profile.kind,
          path: profile.path,
        ),
        canonicalPath: p.normalize(p.absolute(canonical)),
      );
    }
    return allowed;
  }

  Future<File?> _profileFile(
    _AllowedBrowserProfile profile,
    String name,
  ) async {
    final candidate = p.join(profile.canonicalPath, name);
    final type = await FileSystemEntity.type(candidate, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.file) {
      throw BrowserAccessException(
        'Browser data is not a regular file: ${profile.source.id}/$name',
      );
    }
    final canonical = p.normalize(
      p.absolute(await File(candidate).resolveSymbolicLinks()),
    );
    if (!_browserPathWithin(profile.canonicalPath, canonical)) {
      throw BrowserAccessException(
        'Browser data is outside the allowed profile: ${profile.source.id}',
      );
    }
    return File(canonical);
  }

  _BrowserMatch _browserMatch({
    required _AllowedBrowserProfile profile,
    required BrowserSearchSource source,
    required String url,
    required String title,
    required DateTime? occurredAt,
  }) {
    final digest = sha256.convert(utf8.encode(url)).toString();
    final displayTitle = title.trim().isEmpty ? url : title.trim();
    final evidence = ConnectorEvidence(
      id:
          'browser:${profile.source.id}:${source.name}:'
          '${digest.substring(0, 16)}',
      kind: ConnectorEvidenceKind.browser,
      title: displayTitle,
      content:
          'Perfil: ${profile.source.name}\n'
          'Origem: ${source.name}\n'
          'Título: $displayTitle\n'
          'URL: $url',
      uri: Uri.tryParse(url),
      startedAt: occurredAt,
      endedAt: occurredAt,
    );
    return _BrowserMatch(
      profile: profile,
      source: source,
      url: url,
      title: displayTitle,
      occurredAt: occurredAt,
      evidence: evidence,
    );
  }

  bool _sameProfile(
    _AllowedBrowserProfile? current,
    _AllowedBrowserProfile expected,
  ) =>
      current != null &&
      current.source.kind == expected.source.kind &&
      _browserSamePath(current.canonicalPath, expected.canonicalPath);
}

class _SearchBrowserTool implements AgentConnectorTool {
  const _SearchBrowserTool(this.connector);

  final BrowserConnector connector;

  @override
  ConnectorAccess get access => ConnectorAccess.read;

  @override
  LlmToolDefinition get definition => const LlmToolDefinition(
    name: searchBrowserToolName,
    description:
        'Busca no histórico e nos favoritos de perfis de navegador autorizados.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string'},
        'profileIds': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'source': {
          'type': 'string',
          'enum': ['history', 'bookmarks', 'all'],
        },
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 20},
      },
      'required': ['query'],
    },
  );

  @override
  ConnectorApproval approval(Map<String, Object?> arguments) =>
      const ConnectorApproval(
        toolName: searchBrowserToolName,
        access: ConnectorAccess.read,
        title: 'Buscar no navegador',
        description: 'Busca somente nos perfis de navegador autorizados.',
      );

  @override
  Future<ConnectorToolResult> execute(
    Map<String, Object?> arguments,
    ConnectorRunContext context,
  ) => connector.search(arguments, context);
}

class BrowserAccessException implements Exception {
  const BrowserAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _AllowedBrowserProfile {
  const _AllowedBrowserProfile({
    required this.source,
    required this.canonicalPath,
  });

  final BrowserProfile source;
  final String canonicalPath;
}

class _BrowserMatch {
  const _BrowserMatch({
    required this.profile,
    required this.source,
    required this.url,
    required this.title,
    required this.occurredAt,
    required this.evidence,
  });

  final _AllowedBrowserProfile profile;
  final BrowserSearchSource source;
  final String url;
  final String title;
  final DateTime? occurredAt;
  final ConnectorEvidence evidence;

  Map<String, Object?> toJson() => {
    'profileId': profile.source.id,
    'profileName': profile.source.name,
    'source': source.name,
    'url': url,
    'title': title,
    if (occurredAt != null) 'occurredAt': occurredAt!.toIso8601String(),
    'evidenceId': evidence.id,
  };
}

BrowserSearchSource _browserSource(Object? value) {
  final name = value is String ? value.trim() : 'all';
  return switch (name) {
    'history' => BrowserSearchSource.history,
    'bookmarks' => BrowserSearchSource.bookmarks,
    'all' => BrowserSearchSource.all,
    _ => throw FormatException('Unsupported browser source: $name'),
  };
}

String _requiredBrowserString(Map<String, Object?> arguments, String key) {
  final value = (arguments[key] as String? ?? '').trim();
  if (value.isEmpty) throw FormatException('$key is required');
  return value;
}

List<String> _browserStrings(Object? value) =>
    value is List
        ? value
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
        : const [];

int _browserLimit(Object? value) {
  final limit = value is num ? value.toInt() : 10;
  if (limit < 1 || limit > maxBrowserSearchResults) {
    throw RangeError.range(limit, 1, maxBrowserSearchResults, 'limit');
  }
  return limit;
}

String _likePattern(String query) {
  final escaped = query
      .toLowerCase()
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
  return '%$escaped%';
}

bool _containsIgnoreCase(String value, String query) =>
    value.toLowerCase().contains(query.toLowerCase());

DateTime? _chromiumDate(Object? value) {
  final microseconds = _integer(value);
  if (microseconds == null || microseconds <= 0) return null;
  const windowsToUnixEpochMicroseconds = 11644473600000000;
  final unixMicroseconds = microseconds - windowsToUnixEpochMicroseconds;
  if (unixMicroseconds < 0) return null;
  return DateTime.fromMicrosecondsSinceEpoch(unixMicroseconds, isUtc: true);
}

DateTime? _unixMicrosecondsDate(Object? value) {
  final microseconds = _integer(value);
  if (microseconds == null || microseconds <= 0) return null;
  return DateTime.fromMicrosecondsSinceEpoch(microseconds, isUtc: true);
}

int? _integer(Object? value) => switch (value) {
  int value => value,
  String value => int.tryParse(value),
  _ => null,
};

int _newestFirst(_BrowserMatch left, _BrowserMatch right) {
  final leftDate = left.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final rightDate = right.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return rightDate.compareTo(leftDate);
}

bool _browserPathWithin(String root, String candidate) {
  final normalizedRoot = _browserComparisonPath(root);
  final normalizedCandidate = _browserComparisonPath(candidate);
  return normalizedCandidate != normalizedRoot &&
      p.isWithin(normalizedRoot, normalizedCandidate);
}

bool _browserSamePath(String left, String right) =>
    _browserComparisonPath(left) == _browserComparisonPath(right);

String _browserComparisonPath(String path) {
  final normalized = p.normalize(p.absolute(path));
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}
