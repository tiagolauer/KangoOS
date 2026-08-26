import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
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
    final snippetRepository = SqliteSnippetRepository(database);
    final embeddingProvider = _FakeEmbeddingProvider();
    final episodes = SqliteEpisodeRepository(database);
    final snippets = SnippetService(
      repository: snippetRepository,
      semanticSearch: SemanticSearch(
        repository: snippetRepository,
        embeddingProvider: embeddingProvider,
      ),
    );
    final memory = MemoryService(
      activities: SqliteActivityRepository(database),
      summaries: SqliteSummaryRepository(database),
      episodes: episodes,
      queryEngine: MemoryQueryEngine(
        episodes: episodes,
        embeddingProvider: embeddingProvider,
      ),
    );
    final conversations = SqliteConversationRepository(database);
    server = KangoMcpServer(
      snippets: snippets,
      memory: memory,
      agent: MemoryAgent(
        memory: memory,
        snippets: snippets,
        conversations: conversations,
      ),
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

  test('tools/list advertises snippet and structured-memory tools', () async {
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
        'search_memories',
        'search_memories_semantic',
        'search_memories_by_time',
        'get_memory_episode',
        'list_recent_memories',
        'find_related_memories',
        'investigate_memory',
        'deep_study',
        'search_entities',
        'search_projects',
        'forget_memory',
        'get_daily_summary',
        'get_weekly_summary',
        'ask_kango_ltm',
        'create_kango_memory',
        'remember',
      },
    );
  });

  test('agentic tools return reflection and a DeepStudy report', () async {
    await database.createSnippet(SnippetsCompanion.insert(
      title: 'Kango evidence',
      content: 'Kango evidence retrieval',
    ));
    final investigation = await server.handleMessage(
      _call('investigate_memory', {'query': 'Kango evidence'}),
    );
    final study = await server.handleMessage(
      _call('deep_study', {'query': 'Kango evidence'}),
    );

    final investigationJson = jsonDecode(_text(investigation!)) as Map;
    final studyJson = jsonDecode(_text(study!)) as Map;
    expect(investigationJson['reflection'], isA<Map>());
    expect(studyJson['report'], contains('# DeepStudy: Kango evidence'));
  });

  test('semantic and temporal memory tools use distinct retrieval modes',
      () async {
    final episodes = SqliteEpisodeRepository(database);
    final id = await episodes.create(NewMemoryEpisode(
      sourceKey: 'mcp-mode-test',
      startedAt: DateTime(2026, 8, 24, 10),
      endedAt: DateTime(2026, 8, 24, 11),
      title: 'Architecture review',
      summary: 'Reviewed storage boundaries',
      applications: const ['Code'],
      urls: const [],
      topics: const ['architecture'],
      entities: const [],
      sourceActivityIds: const [],
    ));
    await episodes.setEmbedding(id, const [1, 0, 0], 'fake');

    final semanticResponse = await server.handleMessage(
      _call('search_memories_semantic', {'query': 'unrelated semantics'}),
    );
    final semantic =
        jsonDecode(_text(semanticResponse!)) as Map<String, dynamic>;
    final semanticMemory =
        (semantic['memories'] as List).single as Map<String, dynamic>;
    expect(semanticMemory['semanticMatch'], isTrue);
    expect(semanticMemory['lexicalMatch'], isFalse);

    final temporalResponse = await server.handleMessage(
      _call('search_memories_by_time', {'query': '2026-08-24'}),
    );
    final temporal =
        jsonDecode(_text(temporalResponse!)) as Map<String, dynamic>;
    final temporalMemory =
        (temporal['memories'] as List).single as Map<String, dynamic>;
    expect(temporalMemory['id'], id);
    expect(temporalMemory['semanticMatch'], isFalse);
    expect(temporalMemory['lexicalMatch'], isFalse);
  });

  test('structured-memory tools reject unsafe limits', () async {
    final response = await server.handleMessage(
      _call('search_memories', {'query': 'anything', 'limit': 0}),
    );

    expect(response!['result']['isError'], isTrue);
    expect(_text(response), contains('between 1 and'));
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

  test('ask_kango_ltm returns activity and summaries within the parsed range',
      () async {
    final now = DateTime.now();
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'code.exe',
      windowTitle: 'today-work.dart',
      capturedAt: Value(now),
    ));
    await database.insertActivitySummary(ActivitySummariesCompanion.insert(
      kind: SummaryKind.periodic,
      periodStart: now.subtract(const Duration(minutes: 20)),
      periodEnd: now,
      content: 'Recap of today.',
    ));

    final response = await server.handleMessage(
        _call('ask_kango_ltm', {'query': 'what did I do today?'}));
    final result = jsonDecode(_text(response!)) as Map<String, dynamic>;

    expect((result['activities'] as List).single['windowTitle'],
        'today-work.dart');
    expect((result['summaries'] as List).single['content'], 'Recap of today.');
  });

  test('ask_kango_ltm with keywords full-text-searches activity in range',
      () async {
    final now = DateTime.now();
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'code.exe',
      windowTitle: 'drift migration notes',
      capturedAt: Value(now),
    ));
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'chrome.exe',
      windowTitle: 'unrelated tab',
      capturedAt: Value(now),
    ));

    final response = await server.handleMessage(
        _call('ask_kango_ltm', {'query': 'today', 'keywords': 'drift'}));
    final result = jsonDecode(_text(response!)) as Map<String, dynamic>;

    final activities = result['activities'] as List;
    expect(activities, hasLength(1));
    expect(activities.single['windowTitle'], 'drift migration notes');
  });

  test('ask_kango_ltm requires a query', () async {
    final response = await server.handleMessage(_call('ask_kango_ltm'));
    expect(response!['result']['isError'], true);
  });

  test(
      'create_kango_memory saves a durable summary retrievable by ask_kango_ltm',
      () async {
    final createResponse = await server.handleMessage(
        _call('create_kango_memory', {'content': 'Remember this.'}));
    final created = jsonDecode(_text(createResponse!)) as Map<String, dynamic>;
    expect(created['kind'], 'durable');
    expect(created['content'], 'Remember this.');

    final askResponse =
        await server.handleMessage(_call('ask_kango_ltm', {'query': 'today'}));
    final result = jsonDecode(_text(askResponse!)) as Map<String, dynamic>;
    expect((result['summaries'] as List).single['content'], 'Remember this.');
  });

  test('create_kango_memory requires content', () async {
    final response = await server.handleMessage(_call('create_kango_memory'));
    expect(response!['result']['isError'], true);
  });

  test('semantic search without a semantic search instance reports an error',
      () async {
    final serverWithoutSemantic = KangoMcpServer(
      snippets: SnippetService(
        repository: SqliteSnippetRepository(database),
      ),
      memory: MemoryService(
        activities: SqliteActivityRepository(database),
        summaries: SqliteSummaryRepository(database),
      ),
    );
    final response = await serverWithoutSemantic.handleMessage(
      _call('search_snippets', {'query': 'x', 'semantic': true}),
    );
    expect(response!['result']['isError'], true);
    expect(_text(response), contains('not available'));
  });
}
