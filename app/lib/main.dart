import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'snippet_list_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supportDir = await getApplicationSupportDirectory();
  final database = KangoosDatabase.native(File(p.join(supportDir.path, 'kangoos.db')));
  runApp(KangoosApp(database: database));
}

class KangoosApp extends StatelessWidget {
  const KangoosApp({super.key, required this.database});

  final KangoosDatabase database;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KangoOS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: SnippetListScreen(database: database),
    );
  }
}
