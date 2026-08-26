import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';

class TestEmbeddingProvider implements EmbeddingProvider {
  const TestEmbeddingProvider();

  @override
  String get id => 'test';

  @override
  Future<List<double>> embed(String text) async => const [1, 0];
}

class TestServices {
  TestServices(
    this.database, {
    EmbeddingProvider embeddingProvider = const TestEmbeddingProvider(),
  }) {
    snippetRepository = SqliteSnippetRepository(database);
    semanticSearch = SemanticSearch(
      repository: snippetRepository,
      embeddingProvider: embeddingProvider,
    );
    snippets = SnippetService(
      repository: snippetRepository,
      semanticSearch: semanticSearch,
    );
    conversations = SqliteConversationRepository(database);
    episodes = SqliteEpisodeRepository(database);
    activities = SqliteActivityRepository(database);
    summaries = SqliteSummaryRepository(database);
    memory = MemoryService(
      database: database,
      activities: activities,
      summaries: summaries,
      episodes: episodes,
      queryEngine: MemoryQueryEngine(
        episodes: episodes,
        summaries: summaries,
        conversations: conversations,
        snippets: snippetRepository,
        activities: activities,
        embeddingProvider: embeddingProvider,
      ),
    );
  }

  final KangoosDatabase database;
  late final SnippetRepository snippetRepository;
  late final SemanticSearch semanticSearch;
  late final SnippetService snippets;
  late final MemoryService memory;
  late final ConversationRepository conversations;
  late final EpisodeRepository episodes;
  late final ActivityRepository activities;
  late final SummaryRepository summaries;
}
