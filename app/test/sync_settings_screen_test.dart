import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kangoos_app/secure_credential_store.dart';
import 'package:kangoos_app/sync/sync_settings_repository.dart';
import 'package:kangoos_app/sync/sync_settings_screen.dart';

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

void main() {
  late KangoosDatabase database;
  late TestServices services;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = KangoosDatabase.memory();
    services = TestServices(database);
  });
  tearDown(() => database.close());

  testWidgets('save persists the server URL and API token', (tester) async {
    final secureStore = _FakeSecureCredentialStore();
    final repository = SyncSettingsRepository(secureStore: secureStore);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SyncSettingsScreen(
        repository: repository,
        snippetRepository: services.snippetRepository,
        snippets: services.snippets,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Server URL'), 'http://localhost:8080');
    await tester.enterText(
        find.widgetWithText(TextField, 'API token'), 'dev-token');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final saved = await repository.load();
    expect(saved.serverUrl, 'http://localhost:8080');
    expect(saved.apiToken, 'dev-token');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('sync_api_token'), isNull);
  });

  testWidgets('sync now without a server URL shows a validation message',
      (tester) async {
    final repository =
        SyncSettingsRepository(secureStore: _FakeSecureCredentialStore());

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SyncSettingsScreen(
        repository: repository,
        snippetRepository: services.snippetRepository,
        snippets: services.snippets,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();

    expect(find.text('Set a server URL and API token first.'), findsOneWidget);
  });

  testWidgets('plain http to a remote host asks before sending the token',
      (tester) async {
    final repository =
        SyncSettingsRepository(secureStore: _FakeSecureCredentialStore());

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SyncSettingsScreen(
        repository: repository,
        snippetRepository: services.snippetRepository,
        snippets: services.snippets,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Server URL'), 'http://nas.local:8080');
    await tester.enterText(
        find.widgetWithText(TextField, 'API token'), 'dev-token');
    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();

    expect(find.text('Send the token over plain HTTP?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Send the token over plain HTTP?'), findsNothing);
  });

  testWidgets('an unparseable server URL never reaches the sync client',
      (tester) async {
    final repository =
        SyncSettingsRepository(secureStore: _FakeSecureCredentialStore());

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SyncSettingsScreen(
        repository: repository,
        snippetRepository: services.snippetRepository,
        snippets: services.snippets,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Server URL'), 'not a url');
    await tester.enterText(
        find.widgetWithText(TextField, 'API token'), 'dev-token');
    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('not a valid server URL'),
      findsOneWidget,
    );
  });
}
