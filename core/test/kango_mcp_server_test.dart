import 'dart:convert';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/src/mcp/kango_mcp_server.dart';
import 'package:test/test.dart';

class _FakeEmbeddingProvider implements EmbeddingProvider {
  @override
  String get id => 'fake';

  @override
  Future<List<double>> embed(String text) async => const [1, 0, 0];
}

Map<String, dynamic> _call(String tool,
        [Map<String, dynamic> arguments = const {}]) =>
    {
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'tools/call',
      'params': {'name': tool, 'arguments': arguments},
    };

String _text(Map<String, dynamic> response) =>
    ((response['result']['content'] as List).first as Map)['text'] as String;

void main() {
  late KangoosDatabase database;
  late KangoMcpServer server;

  setUp(() {
    database = KangoosDatabase.memory();
    server = KangoMcpServer(
      database: database,
      semanticSearch: SemanticSearch(
          database: database, embeddingProvider: _FakeEmbeddingProvider()),
    );
  });
  tearDown(() => database.close());

  test('initialize echoes the client protocol version and advertises tools',
      () async {
    final response = await server.handleMessage({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'initialize',
      'params': {'protocolVersion': '2025-03-26'},
    });

    expect(response!['result']['protocolVersion'], '2025-03-26');
    expect(response['result']['capabilities'], {'tools': {}});
    expect(response['result']['serverInfo']['name'], 'kangoos');
  });

  test('initialize without a client version falls back to a default', () async {
    final response = await server
        .handleMessage({'jsonrpc': '2.0', 'id': 1, 'method': 'initialize'});
    expect(response!['result']['protocolVersion'], '2024-11-05');
  });

  test('notifications/initialized produces no response', () async {
    final response = await server.handleMessage({
      'jsonrpc': '2.0',
      'method': 'notifications/initialized',
    });
    expect(response, isNull);
  });

  test('unknown method is a JSON-RPC error', () async {
    final response = await server
        .handleMessage({'jsonrpc': '2.0', 'id': 1, 'method': 'bogus'});
    expect(response!['error']['code'], -32601);
  });

  test('tools/list advertises all six snippet tools', () async {
    final response = await server
        .handleMessage({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/list'});
    final names =
        (response!['result']['tools'] as List).map((t) => t['name']).toSet();
    expect(
      names,
      {
        'search_snippets',
        'create_snippet',
        'list_snippets',
        'get_snippet',
        'update_snippet',
        'delete_snippet',
      },
    );
  });

  test('create_snippet then get_snippet round-trips through JSON content',
      () async {
    final createResponse = await server.handleMessage(
      _call('create_snippet',
          {'title': 'Reverse a string', 'content': 'a.split("").reversed'}),
    );
    final created = jsonDecode(_text(createResponse!)) as Map<String, dynamic>;
    expect(created['title'], 'Reverse a string');

    final getResponse =
        await server.handleMessage(_call('get_snippet', {'id': created['id']}));
    final fetched = jsonDecode(_text(getResponse!)) as Map<String, dynamic>;
    expect(fetched['content'], 'a.split("").reversed');
  });

  test('get_snippet reports an error for a missing id', () async {
    final response =
        await server.handleMessage(_call('get_snippet', {'id': 999}));
    expect(response!['result']['isError'], true);
    expect(_text(response), contains('not found'));
  });

  test('search_snippets finds by keyword', () async {
    await server.handleMessage(
      _call('create_snippet',
          {'title': 'Dart string reverse', 'content': 'code'}),
    );

    final response = await server
        .handleMessage(_call('search_snippets', {'query': 'reverse'}));
    final results = jsonDecode(_text(response!)) as List;
    expect(results, hasLength(1));
    expect(results.single['title'], 'Dart string reverse');
  });

  test('update_snippet changes only the given fields', () async {
    final createResponse = await server.handleMessage(
      _call('create_snippet',
          {'title': 'Foo', 'content': 'body', 'language': 'dart'}),
    );
    final id = (jsonDecode(_text(createResponse!)) as Map)['id'];

    await server
        .handleMessage(_call('update_snippet', {'id': id, 'title': 'Bar'}));

    final getResponse =
        await server.handleMessage(_call('get_snippet', {'id': id}));
    final fetched = jsonDecode(_text(getResponse!)) as Map<String, dynamic>;
    expect(fetched['title'], 'Bar');
    expect(fetched['content'], 'body');
    expect(fetched['language'], 'dart');
  });

  test('delete_snippet removes it', () async {
    final createResponse = await server.handleMessage(
        _call('create_snippet', {'title': 'Foo', 'content': 'body'}));
    final id = (jsonDecode(_text(createResponse!)) as Map)['id'];

    final deleteResponse =
        await server.handleMessage(_call('delete_snippet', {'id': id}));
    expect(deleteResponse!['result']['isError'], isNot(true));

    final getResponse =
        await server.handleMessage(_call('get_snippet', {'id': id}));
    expect(getResponse!['result']['isError'], true);
  });

  test('calling an unknown tool is a tool-level error, not a JSON-RPC error',
      () async {
    final response = await server.handleMessage(_call('bogus_tool'));
    expect(response!['error'], isNull);
    expect(response['result']['isError'], true);
    expect(_text(response), contains('Unknown tool'));
  });

  test('semantic search without a semantic search instance reports an error',
      () async {
    final serverWithoutSemantic = KangoMcpServer(database: database);
    final response = await serverWithoutSemantic.handleMessage(
      _call('search_snippets', {'query': 'x', 'semantic': true}),
    );
    expect(response!['result']['isError'], true);
    expect(_text(response), contains('not available'));
  });
}
