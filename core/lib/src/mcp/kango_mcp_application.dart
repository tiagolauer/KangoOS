import 'dart:io';

import '../cli/kango_paths.dart';
import '../database/database.dart';
import '../database/database_configuration.dart';
import '../embedding/providers/ollama_embedding_provider.dart';
import '../infrastructure/sqlite/sqlite_activity_repository.dart';
import '../infrastructure/sqlite/sqlite_conversation_repository.dart';
import '../infrastructure/sqlite/sqlite_episode_repository.dart';
import '../infrastructure/sqlite/sqlite_snippet_repository.dart';
import '../infrastructure/sqlite/sqlite_summary_repository.dart';
import '../llm/llm_settings.dart';
import '../memory/memory_agent.dart';
import '../memory/memory_metrics.dart';
import '../memory/memory_query_engine.dart';
import '../memory/memory_service.dart';
import '../search/semantic_search.dart';
import '../snippets/snippet_service.dart';
import 'kango_mcp_server.dart';

const defaultMcpEmbeddingModel = 'nomic-embed-text';

class KangoMcpApplication {
  const KangoMcpApplication({required this.database, required this.server});

  final KangoosDatabase database;
  final KangoMcpServer server;

  static Future<KangoMcpApplication> open(
    Map<String, String> environment,
  ) async {
    final dbPath =
        environment[databasePathEnvironmentKey] ??
        defaultDbPath(environment: environment);
    final dbFile = File(dbPath);
    await dbFile.parent.create(recursive: true);
    final database = KangoosDatabase.native(
      dbFile,
      encryptionKey: databaseEncryptionKeyFromEnvironment(environment),
    );
    try {
      final embedding = OllamaEmbeddingProvider(
        model:
            environment['KANGOOS_EMBEDDING_MODEL'] ?? defaultMcpEmbeddingModel,
        baseUrl:
            environment['KANGOOS_OLLAMA_BASE_URL'] ?? 'http://localhost:11434',
      );
      final snippetRepository = SqliteSnippetRepository(database);
      final snippets = SnippetService(
        repository: snippetRepository,
        semanticSearch: SemanticSearch(
          repository: snippetRepository,
          embeddingProvider: embedding,
        ),
      );
      final episodes = SqliteEpisodeRepository(database);
      final summaries = SqliteSummaryRepository(database);
      final conversations = SqliteConversationRepository(database);
      final activities = SqliteActivityRepository(database);
      final llmProvider = _llmSettings(environment).buildProvider();
      final memoryMetrics = LocalMemoryMetrics();
      final memoryQueryEngine = MemoryQueryEngine(
        episodes: episodes,
        summaries: summaries,
        conversations: conversations,
        snippets: snippetRepository,
        activities: activities,
        embeddingProvider: embedding,
        metrics: memoryMetrics,
      );
      final memory = MemoryService(
        database: database,
        activities: activities,
        summaries: summaries,
        episodes: episodes,
        queryEngine: memoryQueryEngine,
        metrics: memoryMetrics,
      );
      return KangoMcpApplication(
        database: database,
        server: KangoMcpServer(
          snippets: snippets,
          memory: memory,
          agent: MemoryAgent(memory: memory),
          llmProvider: llmProvider,
        ),
      );
    } catch (error) {
      await database.close();
      rethrow;
    }
  }

  Future<void> close() => database.close();

  static LlmSettings _llmSettings(Map<String, String> environment) {
    final providerName =
        environment['KANGOOS_LLM_PROVIDER'] ?? LlmProviderKind.ollama.name;
    final provider = LlmProviderKind.values.firstWhere(
      (item) => item.name == providerName,
      orElse:
          () => throw StateError('Unknown KANGOOS_LLM_PROVIDER: $providerName'),
    );
    return LlmSettings(
      provider: provider,
      model: environment['KANGOOS_LLM_MODEL'] ?? LlmSettings.defaults.model,
      apiKey: environment['KANGOOS_LLM_API_KEY'] ?? '',
      baseUrl: environment['KANGOOS_LLM_BASE_URL'] ?? '',
      embeddingModel:
          environment['KANGOOS_EMBEDDING_MODEL'] ?? defaultMcpEmbeddingModel,
    );
  }
}
