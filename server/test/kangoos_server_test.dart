import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:kangoos_server/kangoos_server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

class _FakeEmbeddingProvider implements EmbeddingProvider {
  @override
  String get id => 'fake';

  @override
  Future<List<double>> embed(String text) async => const [1, 0, 0];
}

class _FakeLlmProvider implements LlmProvider {
  @override
  String get id => 'fake';

  @override
  Stream<String> chat(List<LlmMessage> messages) =>
      Stream.fromIterable(['Hel', 'lo']);
}

void main() {
  const apiToken = 'test-token';
  late KangoosDatabase database;
  late HttpServer httpServer;
  late Uri baseUrl;

  setUp(() async {
    database = KangoosDatabase.memory();
    final snippetRepository = SqliteSnippetRepository(database);
    final embeddingProvider = _FakeEmbeddingProvider();
    final semanticSearch = SemanticSearch(
        repository: snippetRepository, embeddingProvider: embeddingProvider);
    final snippets = SnippetService(
      repository: snippetRepository,
      semanticSearch: semanticSearch,
    );
    final memory = MemoryService(
      activities: SqliteActivityRepository(database),
      summaries: SqliteSummaryRepository(database),
    );
    final ragChat = RagChat(snippets: snippets, memory: memory);
    final server = KangoosServer(
      snippetRepository: snippetRepository,
      snippets: snippets,
      ragChat: ragChat,
      llmProvider: _FakeLlmProvider(),
      apiToken: apiToken,
    );
    httpServer = await shelf_io.serve(server.build(), 'localhost', 0);
    baseUrl = Uri.parse('http://localhost:${httpServer.port}');
  });

  tearDown(() async {
    await httpServer.close(force: true);
    await database.close();
  });

  Map<String, String> authHeaders() => {
        'authorization': 'Bearer $apiToken',
        'content-type': 'application/json',
      };

  test('GET /health does not require auth', () async {
    final response = await http.get(baseUrl.resolve('/health'));
    expect(response.statusCode, 200);
    expect(jsonDecode(response.body), {'status': 'ok'});
  });

  test('requests without a bearer token are rejected with 401', () async {
    final response = await http.get(baseUrl.resolve('/snippets'));
    expect(response.statusCode, 401);
    expect(response.headers['www-authenticate'], 'Bearer');
  });

  test('requests with a wrong token of the same length are rejected', () async {
    final response = await http.get(
      baseUrl.resolve('/snippets'),
      headers: {'authorization': 'Bearer ${'x' * apiToken.length}'},
    );
    expect(response.statusCode, 401);
  });

  test('create, list, get, update and delete a snippet', () async {
    final createResponse = await http.post(
      baseUrl.resolve('/snippets'),
      headers: authHeaders(),
      body: jsonEncode({
        'title': 'Reverse a string',
        'content': 'input.split("").reversed.join()',
      }),
    );
    expect(createResponse.statusCode, 200);
    final created = jsonDecode(createResponse.body) as Map<String, dynamic>;
    final id = created['id'] as int;
    expect(created['title'], 'Reverse a string');

    final listResponse =
        await http.get(baseUrl.resolve('/snippets'), headers: authHeaders());
    expect(jsonDecode(listResponse.body) as List, hasLength(1));

    final getResponse = await http.get(baseUrl.resolve('/snippets/$id'),
        headers: authHeaders());
    expect(getResponse.statusCode, 200);

    final updateResponse = await http.put(
      baseUrl.resolve('/snippets/$id'),
      headers: authHeaders(),
      body: jsonEncode({'title': 'Reverse a String (Dart)'}),
    );
    expect(updateResponse.statusCode, 200);
    expect((jsonDecode(updateResponse.body) as Map)['title'],
        'Reverse a String (Dart)');

    final deleteResponse = await http.delete(baseUrl.resolve('/snippets/$id'),
        headers: authHeaders());
    expect(deleteResponse.statusCode, 204);

    final getAfterDelete = await http.get(baseUrl.resolve('/snippets/$id'),
        headers: authHeaders());
    expect(getAfterDelete.statusCode, 404);
  });

  test('POST /snippets/<id>/index and /index/missing embed snippets', () async {
    final id = await database
        .createSnippet(SnippetsCompanion.insert(title: 'A', content: 'a'));

    final indexOne = await http.post(baseUrl.resolve('/snippets/$id/index'),
        headers: authHeaders());
    expect(indexOne.statusCode, 200);
    expect((await database.getSnippetById(id))!.embedding, isNotNull);

    await database
        .createSnippet(SnippetsCompanion.insert(title: 'B', content: 'b'));
    final indexMissing = await http.post(baseUrl.resolve('/index/missing'),
        headers: authHeaders());
    expect(indexMissing.statusCode, 200);
    expect(jsonDecode(indexMissing.body), {
      'indexed': 1,
      'failures': <String, String>{},
    });
  });

  test('semantic search finds an indexed snippet', () async {
    final id = await database.createSnippet(SnippetsCompanion.insert(
      title: 'Reverse a string',
      content: 'input.split("").reversed.join()',
    ));
    await http.post(baseUrl.resolve('/snippets/$id/index'),
        headers: authHeaders());

    final response = await http.get(
      baseUrl.resolve('/snippets?q=string&mode=semantic'),
      headers: authHeaders(),
    );
    final results = jsonDecode(response.body) as List;
    expect(results, hasLength(1));
    expect(results.first['title'], 'Reverse a string');
  });

  test('malformed client input is a 400, not a 500', () async {
    final badId = await http.get(baseUrl.resolve('/snippets/abc'),
        headers: authHeaders());
    expect(badId.statusCode, 400);

    final badJson = await http.post(baseUrl.resolve('/snippets'),
        headers: authHeaders(), body: 'not json');
    expect(badJson.statusCode, 400);

    final badTags = await http.post(
      baseUrl.resolve('/snippets'),
      headers: authHeaders(),
      body: jsonEncode({
        'title': 'A',
        'content': 'a',
        'tags': [1, 2]
      }),
    );
    expect(badTags.statusCode, 400);

    final badTimestamp = await http.post(
      baseUrl.resolve('/snippets'),
      headers: authHeaders(),
      body: jsonEncode({'title': 'A', 'content': 'a', 'updatedAt': 'today'}),
    );
    expect(badTimestamp.statusCode, 400);

    final badRole = await http.post(
      baseUrl.resolve('/chat'),
      headers: authHeaders(),
      body: jsonEncode({
        'message': 'hi',
        'history': [
          {'role': 'tool', 'content': 'x'}
        ],
      }),
    );
    expect(badRole.statusCode, 400);
  });

  test('snippet payloads carry an indexed flag instead of the vector',
      () async {
    final id = await database
        .createSnippet(SnippetsCompanion.insert(title: 'A', content: 'a'));

    final before = jsonDecode((await http.get(baseUrl.resolve('/snippets/$id'),
            headers: authHeaders()))
        .body) as Map<String, dynamic>;
    expect(before.containsKey('embedding'), isFalse);
    expect(before['indexed'], isFalse);

    await http.post(baseUrl.resolve('/snippets/$id/index'),
        headers: authHeaders());

    final after = jsonDecode((await http.get(baseUrl.resolve('/snippets/$id'),
            headers: authHeaders()))
        .body) as Map<String, dynamic>;
    expect(after.containsKey('embedding'), isFalse);
    expect(after['indexed'], isTrue);
  });

  test('POST /chat streams the reply over SSE', () async {
    final request = http.Request('POST', baseUrl.resolve('/chat'))
      ..headers.addAll(authHeaders())
      ..body = jsonEncode({'message': 'hi'});
    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    expect(body, contains('"text":"Hel"'));
    expect(body, contains('"text":"lo"'));
  });
}
