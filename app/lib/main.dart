import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'snippet_list_screen.dart';

const defaultEmbeddingModel = 'nomic-embed-text';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supportDir = await getApplicationSupportDirectory();
  final database = KangoosDatabase.native(File(p.join(supportDir.path, 'kangoos.db')));
  final semanticSearch = SemanticSearch(
    database: database,
    embeddingProvider: OllamaEmbeddingProvider(model: defaultEmbeddingModel),
  );
  runApp(KangoosApp(database: database, semanticSearch: semanticSearch));
}

class KangoosApp extends StatelessWidget {
  const KangoosApp({super.key, required this.database, required this.semanticSearch});

  final KangoosDatabase database;
  final SemanticSearch semanticSearch;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KangoOS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: SnippetListScreen(database: database, semanticSearch: semanticSearch),
    );
  }
}
