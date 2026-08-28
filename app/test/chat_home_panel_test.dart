import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kangoos_app/capture/capture_settings_repository.dart';
import 'package:kangoos_app/code_block.dart';
import 'package:kangoos_app/connectors/connector_credentials.dart';
import 'package:kangoos_app/connectors/connector_runtime.dart';
import 'package:kangoos_app/home/chat_home_panel.dart';
import 'package:kangoos_app/secure_credential_store.dart';
import 'package:kangoos_app/settings_repository.dart';
import 'package:kangoos_app/theme/kangoos_theme.dart';

import 'test_services.dart';

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

class _BreakingLlmProvider extends LlmProvider {
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

class _StallingLlmProvider extends LlmProvider {
  final _chunks = StreamController<String>();

  @override
  String get id => 'stalling';

  @override
  Stream<String> chat(List<LlmMessage> messages) => _chunks.stream;

  void emit(String chunk) => _chunks.add(chunk);
}

class _FixedLlmProvider extends LlmProvider {
  _FixedLlmProvider(this.reply);

  final String reply;

  @override
  String get id => 'fixed';

  @override
  Stream<String> chat(List<LlmMessage> messages) => Stream.value(reply);
}

class _RecordingLlmProvider extends LlmProvider {
  List<LlmMessage> messages = const [];

  @override
  String get id => 'recording';

  @override
  Stream<String> chat(List<LlmMessage> messages) {
    this.messages = messages;
    return Stream.value('studied');
  }
}

void main() {
  late KangoosDatabase database;
  late TestServices services;
  late SettingsRepository settingsRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = KangoosDatabase.memory();
    services = TestServices(
      database,
      embeddingProvider: _FakeEmbeddingProvider(),
    );
    settingsRepository = SettingsRepository(
      secureStore: _FakeSecureCredentialStore(),
    );
    await settingsRepository.save(
      const LlmSettings(provider: LlmProviderKind.ollama, model: 'llama3'),
    );
  });
  tearDown(() => database.close());

  Future<void> pumpPanel(
    WidgetTester tester,
    LlmProvider provider, {
    ConnectorRuntime? connectorRuntime,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: KangoosTheme.light,
        home: Scaffold(
          body: ChatHomePanel(
            snippetRepository: services.snippetRepository,
            snippets: services.snippets,
            memory: services.memory,
            conversations: services.conversations,
            settingsRepository: settingsRepository,
            captureSettingsRepository: CaptureSettingsRepository(),
            providerBuilder: (_) => provider,
            connectorRuntime: connectorRuntime,
          ),
        ),
      ),
    );
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

  testWidgets('a stream that dies mid-reply keeps what already arrived', (
    tester,
  ) async {
    await pumpPanel(tester, _BreakingLlmProvider(const ['Half an ', 'answer']));

    await send(tester, 'why did this break?');

    final conversationId = (await database.latestConversationId())!;
    final messages = await database.messagesForConversation(conversationId);
    expect(messages.map((m) => m.role), [LlmRole.user, LlmRole.assistant]);
    expect(messages.last.content, 'Half an answer');

    await drainStreams(tester);
  });

  testWidgets('missing CalDAV credentials do not block the conversation', (
    tester,
  ) async {
    final connectorRepository = SqliteConnectorRepository(database);
    await connectorRepository.upsertSource(
      const ConnectorSourceInput(
        id: 'calendar:primary',
        kind: ConnectorSourceKind.calendar,
        label: 'Calendário CalDAV',
        location: 'https://calendar.example/dav/',
      ),
    );
    final runtime = ConnectorRuntime(
      repository: connectorRepository,
      credentials: ConnectorCredentials(
        secureStore: _FakeSecureCredentialStore(),
      ),
    );
    await pumpPanel(
      tester,
      _FixedLlmProvider('Conversa disponível'),
      connectorRuntime: runtime,
    );

    await send(tester, 'Ainda funciona?');

    final conversationId = (await database.latestConversationId())!;
    final messages = await database.messagesForConversation(conversationId);
    expect(messages.last.content, 'Conversa disponível');
    expect(find.text('Conversa disponível'), findsOneWidget);
    await drainStreams(tester);
  });

  testWidgets(
    'stopping a streaming reply keeps the text that already arrived',
    (tester) async {
      final provider = _StallingLlmProvider();
      await pumpPanel(tester, provider);

      await send(tester, 'tell me everything');
      provider.emit('the first half');
      await tester.pump();

      expect(find.textContaining('the first half'), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsOneWidget);
      await tester.tap(find.byIcon(Icons.stop));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byIcon(Icons.stop), findsNothing);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

      final conversationId = (await database.latestConversationId())!;
      final messages = await database.messagesForConversation(conversationId);
      expect(messages.last.content, 'the first half');

      await drainStreams(tester);
    },
  );

  testWidgets('switching conversations never moves an in-flight reply', (
    tester,
  ) async {
    final firstConversation = await services.conversations.create();
    await services.conversations.appendMessage(
      firstConversation,
      LlmRole.user,
      'Conversa A',
    );
    final provider = _StallingLlmProvider();
    await pumpPanel(tester, provider);

    await send(tester, 'Pergunta em andamento');
    provider.emit('Resposta parcial A');
    await tester.pump();
    final secondConversation = await services.conversations.create();
    await services.conversations.appendMessage(
      secondConversation,
      LlmRole.user,
      'Conversa B',
    );

    await tester.tap(find.byIcon(Icons.history));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conversa B'));
    for (var index = 0; index < 20; index++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final firstMessages = await services.conversations.messages(
      firstConversation,
    );
    final secondMessages = await services.conversations.messages(
      secondConversation,
    );
    expect(firstMessages.last.content, 'Resposta parcial A');
    expect(secondMessages.map((message) => message.content), ['Conversa B']);
    expect(find.text('Conversa B'), findsOneWidget);
    expect(find.textContaining('Resposta parcial A'), findsNothing);

    await drainStreams(tester);
  });

  testWidgets('a fenced code block renders as a highlighted code block', (
    tester,
  ) async {
    await pumpPanel(
      tester,
      _FixedLlmProvider('Try:\n\n```dart\nvoid main() {}\n```\n'),
    );

    await send(tester, 'how do I start?');
    await tester.pumpAndSettle();

    expect(find.byType(CodeBlock), findsOneWidget);
    expect(find.textContaining('```'), findsNothing);

    await drainStreams(tester);
  });

  testWidgets('a reply that never starts does not leave an orphan question', (
    tester,
  ) async {
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

  testWidgets('DeepStudy injects an evidence report into the request', (
    tester,
  ) async {
    final provider = _RecordingLlmProvider();
    await services.snippets.create(
      const NewSnippet(
        title: 'Kango architecture',
        content: 'Kango architecture evidence',
      ),
    );
    await pumpPanel(tester, provider);

    await tester.tap(
      find.byTooltip(
        'Enable DeepStudy for a deeper evidence-based investigation',
      ),
    );
    await tester.pump();
    await send(tester, 'Kango architecture');

    expect(
      provider.messages.first.content,
      isNot(contains('# DeepStudy: Kango architecture')),
    );
    expect(
      provider.messages.map((message) => message.content),
      contains(contains('# DeepStudy: Kango architecture')),
    );
    expect(
      provider.messages.map((message) => message.content),
      contains(contains('Trilha de evidências')),
    );

    await drainStreams(tester);
  });
}
