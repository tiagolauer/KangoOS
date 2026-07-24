import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kangoos_app/chat_screen.dart';
import 'package:kangoos_app/settings_repository.dart';

class _FakeProvider implements LlmProvider {
  _FakeProvider(this.chunks);

  final List<String> chunks;

  @override
  String get id => 'fake';

  @override
  Stream<String> chat(List<LlmMessage> messages) => Stream.fromIterable(chunks);
}

class _FakeEmbeddingProvider implements EmbeddingProvider {
  @override
  String get id => 'fake';

  @override
  Future<List<double>> embed(String text) async => const [1, 0, 0];
}

void main() {
  late KangoosDatabase database;
  late SemanticSearch semanticSearch;

  setUp(() {
    database = KangoosDatabase.memory();
    semanticSearch =
        SemanticSearch(database: database, embeddingProvider: _FakeEmbeddingProvider());
  });
  tearDown(() => database.close());

  testWidgets('shows an error when the api key is missing', (tester) async {
    SharedPreferences.setMockInitialValues({
      'llm_provider': 'anthropic',
      'llm_model': 'claude-opus-4-8',
    });
    final repository = SettingsRepository();

    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        database: database,
        semanticSearch: semanticSearch,
        settingsRepository: repository,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hi');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Set an API key in LLM settings first.'), findsOneWidget);
  });

  testWidgets('streams the assistant reply into a bubble', (tester) async {
    SharedPreferences.setMockInitialValues({
      'llm_provider': 'ollama',
      'llm_model': 'llama3',
    });
    final repository = SettingsRepository();

    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(
        database: database,
        semanticSearch: semanticSearch,
        settingsRepository: repository,
        providerBuilder: (_) => _FakeProvider(['Hel', 'lo']),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hi');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('hi'), findsOneWidget);
    expect(find.text('Hello'), findsOneWidget);
  });
}
