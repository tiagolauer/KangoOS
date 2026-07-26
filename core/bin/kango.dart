import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/src/cli/kango_cli.dart';
import 'package:kangoos_core/src/cli/kango_paths.dart';

const _defaultEmbeddingModel = 'nomic-embed-text';

Future<void> main(List<String> arguments) async {
  final dbPath = Platform.environment['KANGOOS_DB_PATH'] ?? defaultDbPath();
  final dbFile = File(dbPath);
  await dbFile.parent.create(recursive: true);

  final database = KangoosDatabase.native(dbFile);
  final semanticSearch = SemanticSearch(
    database: database,
    embeddingProvider: OllamaEmbeddingProvider(
      model: Platform.environment['KANGOOS_EMBEDDING_MODEL'] ??
          _defaultEmbeddingModel,
      baseUrl: Platform.environment['KANGOOS_OLLAMA_BASE_URL'] ??
          'http://localhost:11434',
    ),
  );

  final code = await runKangoCli(arguments,
      database: database, semanticSearch: semanticSearch);
  await database.close();
  exit(code);
}
