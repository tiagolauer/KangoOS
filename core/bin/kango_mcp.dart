import 'dart:convert';
import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/src/cli/kango_paths.dart';
import 'package:kangoos_core/src/mcp/kango_mcp_server.dart';

const _defaultEmbeddingModel = 'nomic-embed-text';

Future<void> main() async {
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
  final server =
      KangoMcpServer(database: database, semanticSearch: semanticSearch);

  final lines = stdin.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.trim().isEmpty) continue;

    final Map<String, dynamic> message;
    try {
      message = jsonDecode(line) as Map<String, dynamic>;
    } catch (e) {
      stdout.writeln(jsonEncode({
        'jsonrpc': '2.0',
        'id': null,
        'error': {'code': -32700, 'message': 'Parse error: $e'},
      }));
      continue;
    }

    final response = await server.handleMessage(message);
    if (response != null) {
      stdout.writeln(jsonEncode(response));
    }
  }

  await database.close();
}
