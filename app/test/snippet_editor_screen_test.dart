import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kangoos_app/secure_credential_store.dart';
import 'package:kangoos_app/settings_repository.dart';
import 'package:kangoos_app/snippet_editor_screen.dart';

class _FakeSecureCredentialStore implements SecureCredentialStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

class _FakeEmbeddingProvider implements EmbeddingProvider {
  @override
  String get id => 'fake';

  @override
  Future<List<double>> embed(String text) async => const [1, 0, 0];
}

class _FakeLlmProvider implements LlmProvider {
  _FakeLlmProvider(this.response);

  final String response;

  @override
  String get id => 'fake';

  @override
  Stream<String> chat(List<LlmMessage> messages) =>
      Stream.fromIterable([response]);
}

void main() {
  late KangoosDatabase database;
  late SemanticSearch semanticSearch;
  late SettingsRepository settingsRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = KangoosDatabase.memory();
    semanticSearch = SemanticSearch(
        database: database, embeddingProvider: _FakeEmbeddingProvider());
    settingsRepository =
        SettingsRepository(secureStore: _FakeSecureCredentialStore());
    await settingsRepository.save(
        const LlmSettings(provider: LlmProviderKind.ollama, model: 'llama3'));
  });
  tearDown(() => database.close());

  testWidgets('suggest tags fills the tags field from the LLM response',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      home: SnippetEditorScreen(
        database: database,
        semanticSearch: semanticSearch,
        settingsRepository: settingsRepository,
        onDone: () {},
        providerBuilder: (_) => _FakeLlmProvider('["dart", "strings"]'),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Reverse a string');
    await tester.enterText(
        find.widgetWithText(TextField, 'Code'), 'input.split("").reversed');

    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();

    expect(find.text('dart, strings'), findsOneWidget);
  });

  testWidgets('suggest tags does nothing without a model configured',
      (tester) async {
    await settingsRepository
        .save(const LlmSettings(provider: LlmProviderKind.ollama, model: ''));

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      home: SnippetEditorScreen(
        database: database,
        semanticSearch: semanticSearch,
        settingsRepository: settingsRepository,
        onDone: () {},
        providerBuilder: (_) => _FakeLlmProvider('["should-not-appear"]'),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Code'), 'body');
    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();

    expect(find.text('Set a model in LLM settings first.'), findsOneWidget);
    expect(find.text('should-not-appear'), findsNothing);
  });

  testWidgets('save with an empty title says so instead of doing nothing',
      (tester) async {
    var done = false;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SnippetEditorScreen(
        database: database,
        semanticSearch: semanticSearch,
        settingsRepository: settingsRepository,
        onDone: () => done = true,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Code'), 'body');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('A title is required.'), findsOneWidget);
    expect(done, isFalse);
    expect(await database.allSnippets(), isEmpty);
  });

  testWidgets('going back with unsaved edits asks before discarding them',
      (tester) async {
    var done = false;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SnippetEditorScreen(
        database: database,
        semanticSearch: semanticSearch,
        settingsRepository: settingsRepository,
        onDone: () => done = true,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Half-written');
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(done, isFalse);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
  });

  testWidgets('deleting a snippet asks first and can be cancelled',
      (tester) async {
    final id = await database.createSnippet(
        SnippetsCompanion.insert(title: 'Precious', content: 'body'));
    final snippet = (await database.getSnippetById(id))!;

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SnippetEditorScreen(
        database: database,
        semanticSearch: semanticSearch,
        settingsRepository: settingsRepository,
        snippet: snippet,
        onDone: () {},
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Delete this snippet?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await database.allSnippets(), hasLength(1));

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(await database.allSnippets(), isEmpty);
  });
}
