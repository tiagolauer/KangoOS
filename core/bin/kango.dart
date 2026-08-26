import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:kangoos_core/src/cli/kango_cli.dart';
import 'package:kangoos_core/src/cli/kango_paths.dart';

const _defaultEmbeddingModel = 'nomic-embed-text';

Future<void> main(List<String> arguments) async {
  final dbPath =
      Platform.environment[databasePathEnvironmentKey] ?? defaultDbPath();
  final dbFile = File(dbPath);
  await dbFile.parent.create(recursive: true);

  final database = KangoosDatabase.native(
    dbFile,
    encryptionKey: databaseEncryptionKeyFromEnvironment(Platform.environment),
  );
  final snippetRepository = SqliteSnippetRepository(database);
  final semanticSearch = SemanticSearch(
    repository: snippetRepository,
    embeddingProvider: OllamaEmbeddingProvider(
      model: Platform.environment['KANGOOS_EMBEDDING_MODEL'] ??
          _defaultEmbeddingModel,
      baseUrl: Platform.environment['KANGOOS_OLLAMA_BASE_URL'] ??
          'http://localhost:11434',
    ),
  );
  final snippetService = SnippetService(
    repository: snippetRepository,
    semanticSearch: semanticSearch,
  );

  final code = await runKangoCli(arguments, snippets: snippetService);
  await database.close();
  exit(code);
}
