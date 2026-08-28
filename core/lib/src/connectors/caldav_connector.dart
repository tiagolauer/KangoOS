import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../llm/llm_provider.dart';
import 'agent_connector.dart';
import 'bounded_http_response.dart';

const maxCalendarConnectorResults = 20;
const maxCalendarConnectorResponseBytes = 4 * 1024 * 1024;
const searchCalendarEventsToolName = 'search_calendar_events';
const getCalendarEventToolName = 'get_calendar_event';
const createCalendarEventToolName = 'create_calendar_event';
const updateCalendarEventToolName = 'update_calendar_event';
const deleteCalendarEventToolName = 'delete_calendar_event';

class CalDavConnector {
  CalDavConnector({
    required Uri calendarUri,
    required String username,
    required String password,
    http.Client? client,
    String Function()? uidFactory,
  }) : _calendarUri = _normalizeCalendarUri(calendarUri),
       _username = _requiredCredential(username, 'username'),
       _password = _requiredCredential(password, 'password'),
       _client = client ?? http.Client(),
       _ownsClient = client == null,
       _uidFactory = uidFactory ?? _newUid {
    if (_username.contains(':')) {
      throw ArgumentError.value(username, 'username', 'must not contain :');
    }
  }

  final Uri _calendarUri;
  final String _username;
  final String _password;
  final http.Client _client;
  final bool _ownsClient;
  final String Function() _uidFactory;

  List<AgentConnectorTool> get tools => [
    _CalDavTool(
      definition: const LlmToolDefinition(
        name: searchCalendarEventsToolName,
        description:
            'Busca eventos no calendário conectado por texto e intervalo ISO-8601.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'query': {'type': 'string'},
            'start': {'type': 'string'},
            'end': {'type': 'string'},
            'limit': {
              'type': 'integer',
              'minimum': 1,
              'maximum': maxCalendarConnectorResults,
            },
          },
        },
      ),
      access: ConnectorAccess.read,
      execute: _search,
    ),
    _CalDavTool(
      definition: const LlmToolDefinition(
        name: getCalendarEventToolName,
        description: 'Lê um evento do calendário pela URL retornada na busca.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'eventUrl': {'type': 'string'},
          },
          'required': ['eventUrl'],
        },
      ),
      access: ConnectorAccess.read,
      execute: _get,
    ),
    _CalDavTool(
      definition: const LlmToolDefinition(
        name: createCalendarEventToolName,
        description:
            'Cria um evento somente depois da confirmação explícita do usuário.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
            'start': {'type': 'string'},
            'end': {'type': 'string'},
            'description': {'type': 'string'},
            'location': {'type': 'string'},
          },
          'required': ['title', 'start', 'end'],
        },
      ),
      access: ConnectorAccess.write,
      execute: _create,
    ),
    _CalDavTool(
      definition: const LlmToolDefinition(
        name: updateCalendarEventToolName,
        description:
            'Atualiza um evento somente depois da confirmação explícita do usuário.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'eventUrl': {'type': 'string'},
            'title': {'type': 'string'},
            'start': {'type': 'string'},
            'end': {'type': 'string'},
            'description': {'type': 'string'},
            'location': {'type': 'string'},
            'etag': {'type': 'string'},
          },
          'required': ['eventUrl'],
        },
      ),
      access: ConnectorAccess.write,
      execute: _update,
    ),
    _CalDavTool(
      definition: const LlmToolDefinition(
        name: deleteCalendarEventToolName,
        description:
            'Exclui um evento somente depois da confirmação explícita do usuário.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'eventUrl': {'type': 'string'},
            'etag': {'type': 'string'},
          },
          'required': ['eventUrl'],
        },
      ),
      access: ConnectorAccess.write,
      execute: _delete,
    ),
  ];

  void close() {
    if (_ownsClient) _client.close();
  }

  Future<ConnectorToolResult> _search(
    Map<String, Object?> arguments,
    ConnectorRunContext context,
  ) async {
    final query = _optionalString(arguments, 'query');
    final start = _optionalDateTime(arguments, 'start');
    final end = _optionalDateTime(arguments, 'end');
    if (start != null && end != null && !end.isAfter(start)) {
      throw const FormatException('end must be after start');
    }
    final limit = _limit(arguments);
    final response = await _send(
      'REPORT',
      _calendarUri,
      context,
      toolName: searchCalendarEventsToolName,
      access: ConnectorAccess.read,
      body: _calendarQuery(query: query, start: start, end: end),
      headers: const {
        'content-type': 'application/xml; charset=utf-8',
        'depth': '1',
      },
    );
    _expectStatus(response, const {200, 207}, 'search calendar events');
    var events = _parseMultiStatus(response.body);
    if (query != null) {
      final normalized = query.toLowerCase();
      events = events
          .where((event) => event.searchText.contains(normalized))
          .toList(growable: false);
    }
    events = events.take(limit).toList(growable: false);
    return _eventResult(events);
  }

  Future<ConnectorToolResult> _get(
    Map<String, Object?> arguments,
    ConnectorRunContext context,
  ) async {
    final event = await _readEvent(
      _eventUri(arguments),
      context,
      toolName: getCalendarEventToolName,
      access: ConnectorAccess.read,
    );
    return _eventResult([event]);
  }

  Future<ConnectorToolResult> _create(
    Map<String, Object?> arguments,
    ConnectorRunContext context,
  ) async {
    final title = _requiredString(arguments, 'title');
    final start = _requiredDateTime(arguments, 'start');
    final end = _requiredDateTime(arguments, 'end');
    _validateRange(start, end);
    final uid = _uidFactory();
    if (uid.trim().isEmpty) {
      throw StateError('uid factory returned an empty id');
    }
    final event = _CalendarEvent(
      uri: _uriForUid(uid),
      uid: uid,
      title: title,
      start: start,
      end: end,
      description: _optionalString(arguments, 'description'),
      location: _optionalString(arguments, 'location'),
    );
    final response = await _send(
      'PUT',
      event.uri,
      context,
      toolName: createCalendarEventToolName,
      access: ConnectorAccess.write,
      body: _calendarData(event),
      headers: const {
        'content-type': 'text/calendar; charset=utf-8',
        'if-none-match': '*',
      },
    );
    _expectStatus(response, const {200, 201, 204}, 'create calendar event');
    return _eventResult([
      _CalendarEvent(
        uri: event.uri,
        uid: event.uid,
        title: event.title,
        start: event.start,
        end: event.end,
        description: event.description,
        location: event.location,
        etag: response.headers['etag'],
      ),
    ]);
  }

  Future<ConnectorToolResult> _update(
    Map<String, Object?> arguments,
    ConnectorRunContext context,
  ) async {
    final uri = _eventUri(arguments);
    final current = await _readEvent(
      uri,
      context,
      toolName: updateCalendarEventToolName,
      access: ConnectorAccess.write,
    );
    final start = _optionalDateTime(arguments, 'start') ?? current.start;
    final end = _optionalDateTime(arguments, 'end') ?? current.end;
    _validateRange(start, end);
    final updated = current.copyWith(
      title: _optionalString(arguments, 'title') ?? current.title,
      start: start,
      end: end,
      description:
          arguments.containsKey('description')
              ? _optionalString(arguments, 'description')
              : current.description,
      location:
          arguments.containsKey('location')
              ? _optionalString(arguments, 'location')
              : current.location,
    );
    final etag = _optionalString(arguments, 'etag') ?? current.etag;
    final response = await _send(
      'PUT',
      uri,
      context,
      toolName: updateCalendarEventToolName,
      access: ConnectorAccess.write,
      body: _calendarData(updated),
      headers: {
        'content-type': 'text/calendar; charset=utf-8',
        if (etag != null) 'if-match': etag,
      },
    );
    _expectStatus(response, const {200, 201, 204}, 'update calendar event');
    return _eventResult([
      _CalendarEvent(
        uri: updated.uri,
        uid: updated.uid,
        title: updated.title,
        start: updated.start,
        end: updated.end,
        description: updated.description,
        location: updated.location,
        etag: response.headers['etag'] ?? etag,
      ),
    ]);
  }

  Future<ConnectorToolResult> _delete(
    Map<String, Object?> arguments,
    ConnectorRunContext context,
  ) async {
    final uri = _eventUri(arguments);
    final etag = _optionalString(arguments, 'etag');
    final response = await _send(
      'DELETE',
      uri,
      context,
      toolName: deleteCalendarEventToolName,
      access: ConnectorAccess.write,
      headers: {if (etag != null) 'if-match': etag},
    );
    _expectStatus(response, const {200, 204}, 'delete calendar event');
    return ConnectorToolResult(
      data: {'deleted': true, 'eventUrl': uri.toString()},
    );
  }

  Future<_CalendarEvent> _readEvent(
    Uri uri,
    ConnectorRunContext context, {
    required String toolName,
    required ConnectorAccess access,
  }) async {
    final response = await _send(
      'GET',
      uri,
      context,
      toolName: toolName,
      access: access,
    );
    _expectStatus(response, const {200}, 'read calendar event');
    return _parseCalendarData(
      response.body,
      uri,
      etag: response.headers['etag'],
    );
  }

  ConnectorToolResult _eventResult(List<_CalendarEvent> events) =>
      ConnectorToolResult(
        data: {
          'events': events.map((event) => event.toJson()).toList(),
          'count': events.length,
        },
        evidence: events.map(_evidence).toList(growable: false),
      );

  ConnectorEvidence _evidence(_CalendarEvent event) => ConnectorEvidence(
    id: 'calendar:${sha256.convert(utf8.encode(event.uri.toString()))}',
    kind: ConnectorEvidenceKind.calendar,
    title: event.title,
    content: [
      '${event.start.toIso8601String()} - ${event.end.toIso8601String()}',
      if (event.location != null) event.location!,
      if (event.description != null) event.description!,
    ].join('\n'),
    uri: event.uri,
    startedAt: event.start,
    endedAt: event.end,
  );

  Future<http.Response> _send(
    String method,
    Uri uri,
    ConnectorRunContext context, {
    required String toolName,
    required ConnectorAccess access,
    String? body,
    Map<String, String> headers = const {},
  }) async {
    final safeUri = method == 'REPORT' ? _calendarUri : _validateEventUri(uri);
    final request =
        http.Request(method, safeUri)
          ..followRedirects = false
          ..headers.addAll({
            'authorization':
                'Basic ${base64Encode(utf8.encode('$_username:$_password'))}',
            ...headers,
          });
    if (body != null) request.body = body;
    await context.guard(toolName, access);
    final streamed = await _bounded(_client.send(request), context);
    return readBoundedHttpResponse(
      streamed,
      context,
      maxBytes: maxCalendarConnectorResponseBytes,
    );
  }

  List<_CalendarEvent> _parseMultiStatus(String body) {
    final document = XmlDocument.parse(body);
    final events = <_CalendarEvent>[];
    for (final response in document.descendants.whereType<XmlElement>().where(
      (element) => element.name.local == 'response',
    )) {
      final href = _descendantText(response, 'href');
      final data = _descendantText(response, 'calendar-data');
      if (href == null || data == null) continue;
      events.add(
        _parseCalendarData(
          data,
          _resolveEventUri(href),
          etag: _descendantText(response, 'getetag'),
        ),
      );
    }
    return events;
  }

  _CalendarEvent _parseCalendarData(String data, Uri uri, {String? etag}) {
    // ponytail: parses one VEVENT's core fields; add recurrence expansion when instances are required.
    final fields = <String, String>{};
    var insideEvent = false;
    for (final line in _unfoldLines(data)) {
      if (line == 'BEGIN:VEVENT') {
        insideEvent = true;
        continue;
      }
      if (line == 'END:VEVENT') break;
      if (!insideEvent) continue;
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      final name = line.substring(0, separator).split(';').first.toUpperCase();
      fields.putIfAbsent(name, () => line.substring(separator + 1));
    }
    final uid = fields['UID'];
    final title = fields['SUMMARY'];
    final start = fields['DTSTART'];
    final end = fields['DTEND'];
    if (uid == null || title == null || start == null || end == null) {
      throw const FormatException('calendar event is missing required fields');
    }
    return _CalendarEvent(
      uri: _validateEventUri(uri),
      uid: _unescapeCalendarText(uid),
      title: _unescapeCalendarText(title),
      start: _parseCalendarDate(start),
      end: _parseCalendarDate(end),
      description: _nullableCalendarText(fields['DESCRIPTION']),
      location: _nullableCalendarText(fields['LOCATION']),
      etag: etag,
    );
  }

  Uri _eventUri(Map<String, Object?> arguments) {
    final value = _requiredString(arguments, 'eventUrl');
    final parsed = Uri.tryParse(value);
    if (parsed == null) throw const FormatException('eventUrl must be a URL');
    return _validateEventUri(
      parsed.hasScheme ? parsed : _calendarUri.resolveUri(parsed),
    );
  }

  Uri _resolveEventUri(String href) {
    final parsed = Uri.tryParse(href.trim());
    if (parsed == null) throw const FormatException('invalid CalDAV event URL');
    return _validateEventUri(
      parsed.hasScheme ? parsed : _calendarUri.resolveUri(parsed),
    );
  }

  Uri _uriForUid(String uid) {
    final segments = _calendarUri.pathSegments.where((part) => part.isNotEmpty);
    return _validateEventUri(
      _calendarUri.replace(
        pathSegments: [...segments, '$uid.ics'],
        query: null,
        fragment: null,
      ),
    );
  }

  Uri _validateEventUri(Uri candidate) {
    if (!_sameOrigin(_calendarUri, candidate) ||
        candidate.userInfo.isNotEmpty ||
        candidate.query.isNotEmpty ||
        candidate.fragment.isNotEmpty) {
      throw const FormatException(
        'eventUrl must stay within the configured calendar',
      );
    }
    final decodedSegments = candidate.pathSegments;
    if (decodedSegments.any(
      (segment) =>
          segment == '.' ||
          segment == '..' ||
          segment.contains('/') ||
          segment.contains('\\'),
    )) {
      throw const FormatException('eventUrl contains an unsafe path');
    }
    if (candidate.path == _calendarUri.path ||
        !candidate.path.startsWith(_calendarUri.path)) {
      throw const FormatException(
        'eventUrl must stay within the configured calendar',
      );
    }
    return candidate;
  }
}

typedef _CalDavExecutor =
    Future<ConnectorToolResult> Function(
      Map<String, Object?> arguments,
      ConnectorRunContext context,
    );

class _CalDavTool implements AgentConnectorTool {
  const _CalDavTool({
    required this.definition,
    required this.access,
    required _CalDavExecutor execute,
  }) : _execute = execute;

  @override
  final LlmToolDefinition definition;

  @override
  final ConnectorAccess access;

  final _CalDavExecutor _execute;

  @override
  ConnectorApproval approval(Map<String, Object?> arguments) =>
      ConnectorApproval(
        toolName: definition.name,
        access: access,
        title: 'Confirmar alteração no calendário',
        description: switch (definition.name) {
          createCalendarEventToolName => _approvalDescription(
            'Criar evento',
            arguments,
            const ['title', 'start', 'end', 'location', 'description'],
          ),
          updateCalendarEventToolName => _approvalDescription(
            'Atualizar evento',
            arguments,
            const [
              'eventUrl',
              'title',
              'start',
              'end',
              'location',
              'description',
            ],
          ),
          deleteCalendarEventToolName => _approvalDescription(
            'Excluir evento',
            arguments,
            const ['eventUrl'],
          ),
          _ => definition.description,
        },
      );

  @override
  Future<ConnectorToolResult> execute(
    Map<String, Object?> arguments,
    ConnectorRunContext context,
  ) => _execute(arguments, context);
}

String _approvalDescription(
  String action,
  Map<String, Object?> arguments,
  List<String> fields,
) {
  final details = <String>[];
  for (final field in fields) {
    final value = arguments[field];
    if (value == null || '$value'.trim().isEmpty) continue;
    final normalized = '$value'.trim();
    details.add(
      '$field: ${normalized.length > 200 ? '${normalized.substring(0, 200)}…' : normalized}',
    );
  }
  return details.isEmpty ? action : '$action\n${details.join('\n')}';
}

class _CalendarEvent {
  const _CalendarEvent({
    required this.uri,
    required this.uid,
    required this.title,
    required this.start,
    required this.end,
    this.description,
    this.location,
    this.etag,
  });

  final Uri uri;
  final String uid;
  final String title;
  final DateTime start;
  final DateTime end;
  final String? description;
  final String? location;
  final String? etag;

  String get searchText =>
      '$title ${description ?? ''} ${location ?? ''}'.toLowerCase();

  _CalendarEvent copyWith({
    String? title,
    DateTime? start,
    DateTime? end,
    String? description,
    String? location,
    String? etag,
  }) => _CalendarEvent(
    uri: uri,
    uid: uid,
    title: title ?? this.title,
    start: start ?? this.start,
    end: end ?? this.end,
    description: description,
    location: location,
    etag: etag ?? this.etag,
  );

  Map<String, Object?> toJson() => {
    'eventUrl': uri.toString(),
    'uid': uid,
    'title': title,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    if (description != null) 'description': description,
    if (location != null) 'location': location,
    if (etag != null) 'etag': etag,
  };
}

String _calendarQuery({String? query, DateTime? start, DateTime? end}) {
  final textFilter =
      query == null
          ? ''
          : '<c:prop-filter name="SUMMARY"><c:text-match '
              'collation="i;unicode-casemap">${_xmlText(query)}</c:text-match>'
              '</c:prop-filter>';
  final timeRange =
      start == null && end == null
          ? ''
          : '<c:time-range${start == null ? '' : ' start="${_calDavDate(start)}"'}'
              '${end == null ? '' : ' end="${_calDavDate(end)}"'}/>';
  return '<?xml version="1.0" encoding="utf-8"?>'
      '<c:calendar-query xmlns:d="DAV:" '
      'xmlns:c="urn:ietf:params:xml:ns:caldav">'
      '<d:prop><d:getetag/><c:calendar-data/></d:prop>'
      '<c:filter><c:comp-filter name="VCALENDAR">'
      '<c:comp-filter name="VEVENT">$timeRange$textFilter</c:comp-filter>'
      '</c:comp-filter></c:filter></c:calendar-query>';
}

String _calendarData(_CalendarEvent event) => [
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  'PRODID:-//KangoOS//Calendar Connector//PT-BR',
  'BEGIN:VEVENT',
  'UID:${_escapeCalendarText(event.uid)}',
  'DTSTAMP:${_calDavDate(DateTime.now())}',
  'DTSTART:${_calDavDate(event.start)}',
  'DTEND:${_calDavDate(event.end)}',
  'SUMMARY:${_escapeCalendarText(event.title)}',
  if (event.description != null)
    'DESCRIPTION:${_escapeCalendarText(event.description!)}',
  if (event.location != null)
    'LOCATION:${_escapeCalendarText(event.location!)}',
  'END:VEVENT',
  'END:VCALENDAR',
  '',
].join('\r\n');

List<String> _unfoldLines(String value) {
  final lines = const LineSplitter().convert(value);
  final unfolded = <String>[];
  for (final line in lines) {
    if ((line.startsWith(' ') || line.startsWith('\t')) &&
        unfolded.isNotEmpty) {
      unfolded[unfolded.length - 1] += line.substring(1);
    } else {
      unfolded.add(line);
    }
  }
  return unfolded;
}

String _escapeCalendarText(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('\r\n', '\\n')
    .replaceAll('\r', '\\n')
    .replaceAll('\n', '\\n')
    .replaceAll(',', '\\,')
    .replaceAll(';', '\\;');

String _unescapeCalendarText(String value) => value
    .replaceAll('\\n', '\n')
    .replaceAll('\\N', '\n')
    .replaceAll('\\,', ',')
    .replaceAll('\\;', ';')
    .replaceAll('\\\\', '\\');

String? _nullableCalendarText(String? value) {
  if (value == null) return null;
  final decoded = _unescapeCalendarText(value).trim();
  return decoded.isEmpty ? null : decoded;
}

DateTime _parseCalendarDate(String value) {
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$',
  ).firstMatch(value.trim());
  if (match == null) throw FormatException('unsupported calendar date: $value');
  final parts = [
    for (var index = 1; index <= 6; index++)
      int.parse(match.group(index) ?? '0'),
  ];
  if (match.group(7) == 'Z') {
    return DateTime.utc(
      parts[0],
      parts[1],
      parts[2],
      parts[3],
      parts[4],
      parts[5],
    );
  }
  return DateTime(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
}

String _calDavDate(DateTime value) {
  final utc = value.toUtc();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
      '${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
}

String _xmlText(String value) =>
    const HtmlEscape(HtmlEscapeMode.element).convert(value);

String? _descendantText(XmlElement parent, String localName) {
  for (final element in parent.descendants.whereType<XmlElement>()) {
    if (element.name.local == localName) return element.innerText.trim();
  }
  return null;
}

Uri _normalizeCalendarUri(Uri uri) {
  if ((uri.scheme != 'https' &&
          !(uri.scheme == 'http' && _isLoopbackHost(uri.host))) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.query.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    throw ArgumentError.value(
      uri,
      'calendarUri',
      'must use HTTPS, except for loopback development servers',
    );
  }
  final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
  return uri.replace(path: path, query: null, fragment: null);
}

bool _sameOrigin(Uri left, Uri right) =>
    left.scheme == right.scheme &&
    left.host.toLowerCase() == right.host.toLowerCase() &&
    left.port == right.port;

bool _isLoopbackHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1';
}

String _requiredCredential(String value, String name) {
  if (value.isEmpty) throw ArgumentError.value(value, name, 'is required');
  return value;
}

String _requiredString(Map<String, Object?> arguments, String key) {
  final value = arguments[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key is required');
  }
  return value.trim();
}

String? _optionalString(Map<String, Object?> arguments, String key) {
  final value = arguments[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be a string');
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

DateTime _requiredDateTime(Map<String, Object?> arguments, String key) {
  final value = _requiredString(arguments, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('$key must be ISO-8601');
  return parsed;
}

DateTime? _optionalDateTime(Map<String, Object?> arguments, String key) {
  final value = _optionalString(arguments, key);
  if (value == null) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('$key must be ISO-8601');
  return parsed;
}

int _limit(Map<String, Object?> arguments) {
  final value = arguments['limit'];
  final limit =
      value == null
          ? 10
          : value is num
          ? value.toInt()
          : -1;
  if (limit < 1 || limit > maxCalendarConnectorResults) {
    throw const FormatException('limit must be between 1 and 20');
  }
  return limit;
}

void _validateRange(DateTime start, DateTime end) {
  if (!end.isAfter(start)) {
    throw const FormatException('end must be after start');
  }
}

void _expectStatus(
  http.Response response,
  Set<int> expected,
  String operation,
) {
  if (!expected.contains(response.statusCode)) {
    throw StateError('$operation failed with HTTP ${response.statusCode}');
  }
}

Future<T> _bounded<T>(Future<T> future, ConnectorRunContext context) {
  final remaining = context.deadline.difference(DateTime.now());
  if (remaining <= Duration.zero) {
    throw TimeoutException('connector deadline exceeded');
  }
  final bounded = future.timeout(remaining);
  final token = context.cancelToken;
  if (token == null) return bounded;
  return Future.any([
    bounded,
    token.whenCancelled.then<T>(
      (_) => throw const ConnectorCancelledException(),
    ),
  ]);
}

String _newUid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return '${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}@kangoos';
}
