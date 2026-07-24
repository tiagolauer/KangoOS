import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';

import 'package:kangoos_app/snippet_list_screen.dart';

class _FakeEmbeddingProvider implements EmbeddingProvider {
  @override
  String get id => 'fake';

  @override
  Future<List<double>> embed(String text) async => const [1, 0, 0];
}

void main() {
  testWidgets('semantic toggle finds an indexed snippet', (tester) async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final semanticSearch =
        SemanticSearch(database: database, embeddingProvider: _FakeEmbeddingProvider());

    final id = await database.createSnippet(SnippetsCompanion.insert(
      title: 'Reverse a string',
      content: 'input.split("").reversed.join()',
    ));
    await semanticSearch.indexSnippet((await database.getSnippetById(id))!);

    await tester.pumpWidget(MaterialApp(
      home: SnippetListScreen(database: database, semanticSearch: semanticSearch),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'string stuff');
    await tester.pumpAndSettle();

    expect(find.text('Reverse a string'), findsOneWidget);
  });
}
