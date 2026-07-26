import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kangoos_app/capture/capture_settings_repository.dart';
import 'package:kangoos_app/home/chat_home_panel.dart';
import 'package:kangoos_app/secure_credential_store.dart';
import 'package:kangoos_app/settings_repository.dart';
import 'package:kangoos_app/theme/kangoos_theme.dart';

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

class _BreakingLlmProvider implements LlmProvider {
  _BreakingLlmProvider(this.chunksBeforeFailure);

  final List<String> chunksBeforeFailure;

  @override
  String get id => 'breaking';

  @override
  Stream<String> chat(List<LlmMessage> messages) async* {
    for (final chunk in chunksBeforeFailure) {
      yield chunk;
    }
    throw StateError('stream died');
  }
}

void main() {
  late KangoosDatabase database;
  late SettingsRepository settingsRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = KangoosDatabase.memory();
    settingsRepository =
        SettingsRepository(secureStore: _FakeSecureCredentialStore());
    await settingsRepository.save(
        const LlmSettings(provider: LlmProviderKind.ollama, model: 'llama3'));
  });
  tearDown(() => database.close());

  Future<void> pumpPanel(WidgetTester tester, LlmProvider provider) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: KangoosTheme.light,
      home: Scaffold(
          body: ChatHomePanel(
        database: database,
        semanticSearch: SemanticSearch(
            database: database, embeddingProvider: _FakeEmbeddingProvider()),
        settingsRepository: settingsRepository,
        captureSettingsRepository: CaptureSettingsRepository(),
        providerBuilder: (_) => provider,
      )),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> drainStreams(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).last, text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('a stream that dies mid-reply keeps what already arrived',
      (tester) async {
    await pumpPanel(tester, _BreakingLlmProvider(const ['Half an ', 'answer']));

    await send(tester, 'why did this break?');

    final conversationId = (await database.latestConversationId())!;
    final messages = await database.messagesForConversation(conversationId);
    expect(messages.map((m) => m.role), [LlmRole.user, LlmRole.assistant]);
    expect(messages.last.content, 'Half an answer');

    await drainStreams(tester);
  });

  testWidgets('a reply that never starts does not leave an orphan question',
      (tester) async {
    await pumpPanel(tester, _BreakingLlmProvider(const []));

    await send(tester, 'anyone home?');

    final conversationId = (await database.latestConversationId())!;
    expect(await database.messagesForConversation(conversationId), isEmpty);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      'anyone home?',
    );

    await drainStreams(tester);
  });
}
