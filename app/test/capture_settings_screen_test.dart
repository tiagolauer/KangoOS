import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kangoos_app/capture/capture_settings_repository.dart';
import 'package:kangoos_app/capture/capture_settings_screen.dart';

void main() {
  testWidgets('toggling capture off and adding an excluded app persists',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = CaptureSettingsRepository();

    await tester.pumpWidget(MaterialApp(
      home: CaptureSettingsScreen(repository: repository),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'keepass.exe');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('keepass.exe'), findsOneWidget);

    final saved = await repository.load();
    expect(saved.paused, isTrue);
    expect(saved.excludedApps, ['keepass.exe']);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect((await repository.load()).excludedApps, isEmpty);
  });

  testWidgets('changing retention persists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = CaptureSettingsRepository();

    await tester.pumpWidget(MaterialApp(
      home: CaptureSettingsScreen(repository: repository),
    ));
    await tester.pumpAndSettle();

    expect((await repository.load()).retentionDays, defaultRetentionDays);

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forever').last);
    await tester.pumpAndSettle();

    expect((await repository.load()).retentionDays, 0);
  });
}
