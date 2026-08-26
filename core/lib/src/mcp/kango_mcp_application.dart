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
import '../memory/memory_agent.dart';
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
      Map<String, String> environment) async {
    final dbPath = environment[databasePathEnvironmentKey] ??
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
      final memory = MemoryService(
        activities: SqliteActivityRepository(database),
        summaries: SqliteSummaryRepository(database),
        episodes: episodes,
        queryEngine: MemoryQueryEngine(
          episodes: episodes,
          embeddingProvider: embedding,
        ),
      );
      final conversations = SqliteConversationRepository(database);
      return KangoMcpApplication(
        database: database,
        server: KangoMcpServer(
          snippets: snippets,
          memory: memory,
          agent: MemoryAgent(
            memory: memory,
            snippets: snippets,
            conversations: conversations,
          ),
        ),
      );
    } catch (error) {
      await database.close();
      rethrow;
    }
  }

  Future<void> close() => database.close();
}
