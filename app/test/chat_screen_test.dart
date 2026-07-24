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

void main() {
  late KangoosDatabase database;

  setUp(() => database = KangoosDatabase.memory());
  tearDown(() => database.close());

  testWidgets('shows an error when the api key is missing', (tester) async {
    SharedPreferences.setMockInitialValues({
      'llm_provider': 'anthropic',
      'llm_model': 'claude-opus-4-8',
    });
    final repository = SettingsRepository();

    await tester.pumpWidget(MaterialApp(
      home: ChatScreen(database: database, settingsRepository: repository),
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
