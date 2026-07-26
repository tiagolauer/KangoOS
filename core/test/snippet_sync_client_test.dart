import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:test/test.dart';

void main() {
  late KangoosDatabase database;

  setUp(() => database = KangoosDatabase.memory());
  tearDown(() => database.close());

  test('sync throws SyncException when the server rejects the fetch', () async {
    final client = MockClient((request) async => http.Response('nope', 500));
    final syncClient = SnippetSyncClient(
      database: database,
      baseUrl: Uri.parse('http://localhost:1234'),
      apiToken: 'token',
      httpClient: client,
    );

    expect(syncClient.sync(), throwsA(isA<SyncException>()));
  });

  test('sends the bearer token on the fetch request', () async {
    String? seenAuth;
    final client = MockClient((request) async {
      seenAuth = request.headers['authorization'];
      return http.Response('[]', 200);
    });
    final syncClient = SnippetSyncClient(
      database: database,
      baseUrl: Uri.parse('http://localhost:1234'),
      apiToken: 'my-secret-token',
      httpClient: client,
    );

    await syncClient.sync();

    expect(seenAuth, 'Bearer my-secret-token');
  });
}
