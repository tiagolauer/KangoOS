import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kangoos_core/src/connectors/agent_connector.dart';
import 'package:kangoos_core/src/connectors/bounded_http_response.dart';
import 'package:kangoos_core/src/connectors/caldav_connector.dart';
import 'package:test/test.dart';

const _calendarUri = 'https://calendar.example/dav/owner/calendar/';
const _eventData = '''BEGIN:VCALENDAR\r
VERSION:2.0\r
BEGIN:VEVENT\r
UID:event-1\r
DTSTART:20260828T130000Z\r
DTEND:20260828T140000Z\r
SUMMARY:Revisão do Projeto\r
DESCRIPTION:Decidir o próximo passo\r
LOCATION:Sala 2\r
END:VEVENT\r
END:VCALENDAR\r
''';

void main() {
  test(
    'search sends a bounded CalDAV REPORT and returns cited evidence',
    () async {
      var requests = 0;
      final client = MockClient((request) async {
        requests++;
        expect(request.method, 'REPORT');
        expect(request.url.toString(), _calendarUri);
        expect(request.followRedirects, isFalse);
        expect(request.headers['authorization'], startsWith('Basic '));
        final body = request.body;
        expect(body, contains('Revisão'));
        return http.Response('''<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:response>
    <d:href>/dav/owner/calendar/event%201.ics</d:href>
    <d:propstat><d:prop>
      <d:getetag>"v1"</d:getetag>
      <c:calendar-data>$_eventData</c:calendar-data>
    </d:prop></d:propstat>
  </d:response>
</d:multistatus>''', 207);
      });
      final connector = CalDavConnector(
        calendarUri: Uri.parse(_calendarUri),
        username: 'credential-user',
        password: 'credential-secret',
        client: client,
      );
      final result = await AgentConnectorRegistry(
        connector.tools,
      ).execute('search_calendar_events', {
        'query': 'Revisão',
        'start': '2026-08-28T00:00:00Z',
        'end': '2026-08-29T00:00:00Z',
      }, _context());

      expect(requests, 1);
      expect(result.evidence, hasLength(1));
      expect(result.evidence.single.id, startsWith('calendar:'));
      expect(
        result.evidence.single.uri.toString(),
        'https://calendar.example/dav/owner/calendar/event%201.ics',
      );
      expect(result.evidence.single.toJson()['untrusted'], isTrue);
      final encoded = jsonEncode({
        'data': result.data,
        'evidence': result.evidence.map((item) => item.toJson()).toList(),
      });
      expect(encoded, isNot(contains('credential-user')));
      expect(encoded, isNot(contains('credential-secret')));
    },
  );

  test(
    'create, update and delete escape URLs and preserve concurrency tags',
    () async {
      var step = 0;
      final client = MockClient((request) async {
        step++;
        switch (step) {
          case 1:
            expect(request.method, 'PUT');
            expect(
              request.url.toString(),
              'https://calendar.example/dav/owner/calendar/unsafe%20id.ics',
            );
            expect(request.headers['if-none-match'], '*');
            expect(request.body, contains('DESCRIPTION:Detalhes'));
            return http.Response('', 201, headers: {'etag': '"created"'});
          case 2:
            expect(request.method, 'GET');
            return http.Response(_eventData, 200, headers: {'etag': '"v1"'});
          case 3:
            expect(request.method, 'PUT');
            expect(request.headers['if-match'], '"v1"');
            expect(request.body, contains('SUMMARY:Novo título'));
            return http.Response('', 204, headers: {'etag': '"v2"'});
          case 4:
            expect(request.method, 'DELETE');
            expect(request.headers['if-match'], '"v2"');
            return http.Response('', 204);
          default:
            fail('unexpected request: ${request.method} ${request.url}');
        }
      });
      var approvals = 0;
      final connector = CalDavConnector(
        calendarUri: Uri.parse(_calendarUri),
        username: 'user',
        password: 'secret',
        client: client,
        uidFactory: () => 'unsafe id',
      );
      final registry = AgentConnectorRegistry(connector.tools);
      final context = _context(
        approvalRequester: (_) async {
          approvals++;
          return true;
        },
      );

      final created = await registry.execute('create_calendar_event', {
        'title': 'Planejamento',
        'start': '2026-08-28T13:00:00Z',
        'end': '2026-08-28T14:00:00Z',
        'description': 'Detalhes',
      }, context);
      final createdEvent = _singleEvent(created);
      expect(createdEvent['description'], 'Detalhes');
      expect(createdEvent['etag'], '"created"');

      final updated = await registry.execute('update_calendar_event', {
        'eventUrl': 'https://calendar.example/dav/owner/calendar/event-1.ics',
        'title': 'Novo título',
      }, context);
      final updatedEvent = _singleEvent(updated);
      expect(updatedEvent['title'], 'Novo título');
      expect(updatedEvent['description'], 'Decidir o próximo passo');
      expect(updatedEvent['etag'], '"v2"');

      final deleted = await registry.execute('delete_calendar_event', {
        'eventUrl': 'https://calendar.example/dav/owner/calendar/event-1.ics',
        'etag': '"v2"',
      }, context);
      expect((deleted.data as Map<String, Object?>)['deleted'], isTrue);
      expect(step, 4);
      expect(approvals, 3);
    },
  );

  test('calendar text escapes isolated carriage returns', () async {
    late String requestBody;
    final connector = CalDavConnector(
      calendarUri: Uri.parse(_calendarUri),
      username: 'user',
      password: 'secret',
      client: MockClient((request) async {
        requestBody = request.body;
        return http.Response('', 201);
      }),
      uidFactory: () => 'event-1',
    );

    await AgentConnectorRegistry(
      connector.tools,
    ).execute(createCalendarEventToolName, {
      'title': 'Reunião\rATTENDEE:mailto:outside@example.com',
      'start': '2026-08-28T13:00:00Z',
      'end': '2026-08-28T14:00:00Z',
    }, _context());

    expect(
      requestBody,
      contains(r'SUMMARY:Reunião\nATTENDEE:mailto:outside@example.com'),
    );
    expect(requestBody, isNot(contains('Reunião\rATTENDEE')));
  });

  test(
    'event operations reject URLs outside the configured calendar',
    () async {
      final client = MockClient((request) async {
        fail('unsafe URL reached the network: ${request.url}');
      });
      final registry = AgentConnectorRegistry(
        CalDavConnector(
          calendarUri: Uri.parse(_calendarUri),
          username: 'user',
          password: 'secret',
          client: client,
        ).tools,
      );

      for (final unsafe in [
        'https://evil.example/dav/owner/calendar/event.ics',
        'https://calendar.example/dav/owner/calendar-other/event.ics',
        'https://calendar.example/dav/owner/calendar/%2e%2e/secret.ics',
        'https://calendar.example/dav/owner/calendar/event.ics?token=secret',
      ]) {
        await expectLater(
          registry.execute('get_calendar_event', {
            'eventUrl': unsafe,
          }, _context()),
          throwsFormatException,
          reason: unsafe,
        );
      }
    },
  );

  test('calendar rejects streamed responses above the byte limit', () async {
    final connector = CalDavConnector(
      calendarUri: Uri.parse(_calendarUri),
      username: 'user',
      password: 'secret',
      client: MockClient.streaming((request, bodyStream) async {
        return http.StreamedResponse(
          Stream.fromIterable([
            List<int>.filled(maxCalendarConnectorResponseBytes, 65),
            const [65],
          ]),
          207,
        );
      }),
    );

    await expectLater(
      AgentConnectorRegistry(
        connector.tools,
      ).execute(searchCalendarEventsToolName, const {}, _context()),
      throwsA(isA<HttpResponseTooLargeException>()),
    );
  });

  test('calendar writes make no request without explicit approval', () async {
    var requests = 0;
    final connector = CalDavConnector(
      calendarUri: Uri.parse(_calendarUri),
      username: 'user',
      password: 'secret',
      client: MockClient((request) async {
        requests++;
        return http.Response('', 201);
      }),
    );
    final registry = AgentConnectorRegistry(connector.tools);
    final arguments = {
      'title': 'Planejamento',
      'start': '2026-08-28T13:00:00Z',
      'end': '2026-08-28T14:00:00Z',
    };
    final baseContext = ConnectorRunContext(
      surface: ConnectorSurface.desktop,
      deadline: DateTime.now().add(const Duration(seconds: 5)),
      permissionChecker: (_, _, _, _) async => true,
    );

    await expectLater(
      registry.execute(createCalendarEventToolName, arguments, baseContext),
      throwsA(isA<ConnectorApprovalRequiredException>()),
    );
    await expectLater(
      registry.execute(
        createCalendarEventToolName,
        arguments,
        ConnectorRunContext(
          surface: ConnectorSurface.desktop,
          deadline: DateTime.now().add(const Duration(seconds: 5)),
          permissionChecker: (_, _, _, _) async => true,
          approvalRequester: (_) async => false,
        ),
      ),
      throwsA(isA<ConnectorApprovalDeniedException>()),
    );
    expect(requests, 0);
  });

  test('credentials require HTTPS outside loopback', () {
    expect(
      () => CalDavConnector(
        calendarUri: Uri.parse('http://calendar.example/dav/'),
        username: 'user',
        password: 'secret',
      ),
      throwsArgumentError,
    );
    expect(
      () => CalDavConnector(
        calendarUri: Uri.parse('http://127.0.0.1:8080/dav/'),
        username: 'user',
        password: 'secret',
      ),
      returnsNormally,
    );
  });
}

ConnectorRunContext _context({ConnectorApprovalRequester? approvalRequester}) =>
    ConnectorRunContext(
      surface: ConnectorSurface.desktop,
      deadline: DateTime.now().add(const Duration(seconds: 5)),
      permissionChecker: (_, _, _, _) async => true,
      approvalRequester: approvalRequester ?? (_) async => true,
    );

Map<String, Object?> _singleEvent(ConnectorToolResult result) {
  final data = result.data as Map<String, Object?>;
  return (data['events'] as List).single as Map<String, Object?>;
}
