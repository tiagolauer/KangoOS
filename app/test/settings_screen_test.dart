import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kangoos_app/secure_credential_store.dart';
import 'package:kangoos_app/settings_repository.dart';
import 'package:kangoos_app/settings_screen.dart';

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
  testWidgets('save persists the model field', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository =
        SettingsRepository(secureStore: _FakeSecureCredentialStore());

    await tester
        .pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
home: SettingsScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Model'), 'gpt-4o');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final saved = await repository.load();
    expect(saved.model, 'gpt-4o');
    expect(saved.provider, LlmProviderKind.ollama);
  });

  testWidgets('changing provider to Gemini and reasoning mode persists',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository =
        SettingsRepository(secureStore: _FakeSecureCredentialStore());

    await tester
        .pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
home: SettingsScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<LlmProviderKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<ReasoningEffort>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Extra thinking').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final saved = await repository.load();
    expect(saved.provider, LlmProviderKind.gemini);
    expect(saved.reasoningEffort, ReasoningEffort.thinking);
  });

  testWidgets('saving an API key never writes it to SharedPreferences',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final secureStore = _FakeSecureCredentialStore();
    final repository = SettingsRepository(secureStore: secureStore);

    await tester
        .pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
home: SettingsScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<LlmProviderKind>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenAI').last);
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'API key'), 'sk-super-secret');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('llm_api_key'), isNull);
    expect(await secureStore.read('llm_api_key'), 'sk-super-secret');

    final saved = await repository.load();
    expect(saved.apiKey, 'sk-super-secret');
  });
}
