import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:kangoos_server/kangoos_server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main() async {
  final config = EnvConfig.fromEnvironment(Platform.environment);

  final database = KangoosDatabase.native(
    File(config.dbPath),
    encryptionKey: config.databaseEncryptionKey,
  );
  final snippetRepository = SqliteSnippetRepository(database);
  final semanticSearch = SemanticSearch(
    repository: snippetRepository,
    embeddingProvider: OllamaEmbeddingProvider(
      model: config.embeddingModel,
      baseUrl: config.ollamaBaseUrl,
    ),
  );
  final snippets = SnippetService(
    repository: snippetRepository,
    semanticSearch: semanticSearch,
  );
  final activities = SqliteActivityRepository(database);
  final summaries = SqliteSummaryRepository(database);
  final episodes = SqliteEpisodeRepository(database);
  final conversations = SqliteConversationRepository(database);
  final memoryMetrics = LocalMemoryMetrics();
  final memoryQueryEngine = MemoryQueryEngine(
    episodes: episodes,
    summaries: summaries,
    conversations: conversations,
    snippets: snippetRepository,
    activities: activities,
    embeddingProvider: semanticSearch.embeddingProvider,
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
  final ragChat = RagChat(
    snippets: snippets,
    memory: memory,
    agent: MemoryAgent(memory: memory),
    connectorSurface: ConnectorSurface.server,
  );

  final server = KangoosServer(
    snippetRepository: snippetRepository,
    snippets: snippets,
    ragChat: ragChat,
    llmProvider: config.llmSettings.buildProvider(),
    apiToken: config.apiToken,
  );

  final httpServer = await shelf_io.serve(
    server.build(),
    InternetAddress.anyIPv4,
    config.port,
  );
  stdout.writeln('KangoOS server listening on port ${httpServer.port}');
}
