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

class _FakeLlmProvider implements LlmProvider {
  _FakeLlmProvider();

  List<LlmMessage>? lastMessages;

  @override
  String get id => 'fake';

  @override
  Stream<String> chat(List<LlmMessage> messages) {
    lastMessages = messages;
    return Stream.fromIterable(['Hel', 'lo']);
  }
}

void main() {
  ({RagChat chat, SemanticSearch search}) buildRag(
    KangoosDatabase database,
    EmbeddingProvider provider, {
    void Function(Object error)? onError,
    int maxHistoryMessages = 20,
  }) {
    final repository = SqliteSnippetRepository(database);
    final search = SemanticSearch(
      repository: repository,
      embeddingProvider: provider,
    );
    return (
      search: search,
      chat: RagChat(
        snippets: SnippetService(
          repository: repository,
          semanticSearch: search,
        ),
        memory: MemoryService(
          database: database,
          activities: SqliteActivityRepository(database),
          summaries: SqliteSummaryRepository(database),
        ),
        onSemanticSearchError: onError,
        maxHistoryMessages: maxHistoryMessages,
      ),
    );
  }

  test('reply injects retrieved snippets into the system prompt', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final built = buildRag(database, _FakeEmbeddingProvider());
    final semanticSearch = built.search;
    final ragChat = built.chat;

    final id = await database.createSnippet(SnippetsCompanion.insert(
      title: 'Reverse a string',
      content: 'input.split("").reversed.join()',
    ));
    await semanticSearch.indexSnippet((await database.getSnippetById(id))!);

    final provider = _FakeLlmProvider();
    final chunks = await ragChat
        .reply(
            provider: provider,
            history: const [],
            userMessage: 'how do I reverse a string?')
        .toList();

    expect(chunks.join(), 'Hello');
    final systemPrompt = provider.lastMessages!.first;
    expect(systemPrompt.role, LlmRole.system);
    expect(systemPrompt.content,
        contains('Responda sempre em português do Brasil'));
    expect(systemPrompt.content, contains('Reverse a string'));
    expect(provider.lastMessages!.last.content, 'how do I reverse a string?');
  });

  test(
      'reply grounds the system prompt in today\'s captured activity and summaries',
      () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final ragChat = buildRag(database, _FakeEmbeddingProvider()).chat;

    final now = DateTime.now();
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'code.exe',
      windowTitle: 'rag_chat.dart',
      capturedAt: Value(now),
    ));
    await database.insertActivitySummary(ActivitySummariesCompanion.insert(
      kind: SummaryKind.periodic,
      periodStart: now.subtract(const Duration(minutes: 20)),
      periodEnd: now,
      content: 'Fixed the LTM-blind RAG chat bug.',
    ));

    final provider = _FakeLlmProvider();
    await ragChat
        .reply(
            provider: provider,
            history: const [],
            userMessage: 'what did I work on today?')
        .toList();

    final systemPrompt = provider.lastMessages!.first.content;
    expect(systemPrompt, contains('rag_chat.dart'));
    expect(systemPrompt, contains('Fixed the LTM-blind RAG chat bug.'));
  });

  test(
      'reply grounds "yesterday" queries in yesterday\'s activity, not today\'s',
      () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final ragChat = buildRag(database, _FakeEmbeddingProvider()).chat;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'code.exe',
      windowTitle: 'yesterday-work.dart',
      capturedAt: Value(today.subtract(const Duration(hours: 2))),
    ));
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'code.exe',
      windowTitle: 'today-work.dart',
      capturedAt: Value(now),
    ));

    final provider = _FakeLlmProvider();
    await ragChat
        .reply(
            provider: provider,
            history: const [],
            userMessage: 'what did I work on yesterday?')
        .toList();

    final systemPrompt = provider.lastMessages!.first.content;
    expect(systemPrompt, contains('yesterday-work.dart'));
    expect(systemPrompt, isNot(contains('today-work.dart')));
  });

  test('retrieveContext falls back to keyword search with no embeddings',
      () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final ragChat = buildRag(database, _FakeEmbeddingProvider()).chat;

    await database.createSnippet(SnippetsCompanion.insert(
      title: 'Dart string reverse',
      content: 'input.split("").reversed.join()',
    ));

    final context = await ragChat.retrieveContext('reverse');
    expect(context, hasLength(1));
    expect(context.first.title, 'Dart string reverse');
  });

  test('onSemanticSearchError fires when semantic search throws', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    Object? reported;
    final ragChat = buildRag(
      database,
      _ThrowingEmbeddingProvider(),
      onError: (error) => reported = error,
    ).chat;

    await database.createSnippet(SnippetsCompanion.insert(
      title: 'Dart string reverse',
      content: 'input.split("").reversed.join()',
    ));

    final context = await ragChat.retrieveContext('reverse');
    expect(reported, isNotNull);
    expect(context, hasLength(1));
    expect(context.first.title, 'Dart string reverse');
  });

  test('only the tail of a long conversation is replayed', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final ragChat = buildRag(
      database,
      _FakeEmbeddingProvider(),
      maxHistoryMessages: 4,
    ).chat;

    final provider = _FakeLlmProvider();
    final history = [
      for (var i = 0; i < 20; i++)
        LlmMessage(role: LlmRole.user, content: 'turn $i'),
    ];

    await ragChat
        .reply(provider: provider, history: history, userMessage: 'now what?')
        .drain<void>();

    final sent = provider.lastMessages!;
    expect(sent.first.role, LlmRole.system);
    expect(sent.length, 1 + 4 + 1);
    expect(sent[1].content, 'turn 16');
    expect(sent.last.content, 'now what?');
  });

  test('the activity context carries a duration per window', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final ragChat = buildRag(database, _FakeEmbeddingProvider()).chat;

    final now = DateTime.now();
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'code.exe',
      windowTitle: 'main.dart',
      capturedAt: Value(now.subtract(const Duration(minutes: 9))),
    ));
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'chrome.exe',
      windowTitle: 'Docs',
      capturedAt: Value(now.subtract(const Duration(minutes: 4))),
    ));

    final provider = _FakeLlmProvider();
    await ragChat
        .reply(
            provider: provider,
            history: const [],
            userMessage: 'what did I do today?')
        .drain<void>();

    expect(provider.lastMessages!.first.content, contains('main.dart'));
    expect(provider.lastMessages!.first.content, contains('5m]'));
  });
}

class _ThrowingEmbeddingProvider implements EmbeddingProvider {
  @override
  String get id => 'throwing';

  @override
  Future<List<double>> embed(String text) async =>
      throw Exception('embedding provider unreachable');
}
