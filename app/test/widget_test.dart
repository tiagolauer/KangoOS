import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kangoos_app/capture/capture_settings_repository.dart';
import 'package:kangoos_app/main.dart';

class _FakeEmbeddingProvider implements EmbeddingProvider {
  @override
  String get id => 'fake';

  @override
  Future<List<double>> embed(String text) async => const [1, 0, 0];
}

void main() {
  testWidgets('create a snippet and see it in the list', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final database = KangoosDatabase.memory();
    final semanticSearch = SemanticSearch(
        database: database, embeddingProvider: _FakeEmbeddingProvider());

    await tester.pumpWidget(
      KangoosApp(
        database: database,
        semanticSearch: semanticSearch,
        captureSettingsRepository: CaptureSettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No snippets yet. Tap + to add one.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Reverse a string',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Code'),
      'input.split("").reversed.join()',
    );
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('Reverse a string'), findsOneWidget);

    await database.close();
    await tester.pump(const Duration(milliseconds: 200));
  });
}
