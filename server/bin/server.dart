import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_server/kangoos_server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main() async {
  final config = EnvConfig.fromEnvironment(Platform.environment);

  final database = KangoosDatabase.native(File(config.dbPath));
  final semanticSearch = SemanticSearch(
    database: database,
    embeddingProvider: OllamaEmbeddingProvider(
      model: config.embeddingModel,
      baseUrl: config.ollamaBaseUrl,
    ),
  );
  final ragChat = RagChat(database: database, semanticSearch: semanticSearch);

  final server = KangoosServer(
    database: database,
    semanticSearch: semanticSearch,
    ragChat: ragChat,
    llmProvider: config.llmSettings.buildProvider(),
    apiToken: config.apiToken,
  );

  final httpServer = await shelf_io.serve(server.build(), InternetAddress.anyIPv4, config.port);
  stdout.writeln('KangoOS server listening on port ${httpServer.port}');
}
