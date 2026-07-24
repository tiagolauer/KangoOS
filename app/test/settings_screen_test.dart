import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kangoos_app/settings_repository.dart';
import 'package:kangoos_app/settings_screen.dart';

void main() {
  testWidgets('save persists the model field', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = SettingsRepository();

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Model'), 'gpt-4o');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final saved = await repository.load();
    expect(saved.model, 'gpt-4o');
    expect(saved.provider, LlmProviderKind.ollama);
  });
}
