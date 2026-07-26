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
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: CaptureSettingsScreen(repository: repository),
    ));
    await tester.pumpAndSettle();

    await tester
        .tap(find.widgetWithText(SwitchListTile, 'Capture active window'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'keepass.exe');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('keepass.exe'), findsOneWidget);

    final saved = await repository.load();
    expect(saved.paused, isTrue);
    expect(saved.excludedApps, ['keepass.exe']);

    await tester.ensureVisible(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect((await repository.load()).excludedApps, isEmpty);
  });

  testWidgets('toggling browser URL capture persists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = CaptureSettingsRepository();

    await tester.pumpWidget(MaterialApp(
      home: CaptureSettingsScreen(repository: repository),
    ));
    await tester.pumpAndSettle();

    expect((await repository.load()).captureBrowserUrls, isFalse);

    await tester
        .tap(find.widgetWithText(SwitchListTile, 'Capture browser URLs'));
    await tester.pumpAndSettle();

    expect((await repository.load()).captureBrowserUrls, isTrue);
  });

  testWidgets('changing retention persists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = CaptureSettingsRepository();
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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

  testWidgets('enabling visible text capture persists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = CaptureSettingsRepository();

    await tester.pumpWidget(MaterialApp(
      home: CaptureSettingsScreen(repository: repository),
    ));
    await tester.pumpAndSettle();

    expect((await repository.load()).captureVisibleText, isFalse);

    await tester.tap(find.widgetWithText(
        SwitchListTile, 'Capture visible text (experimental)'));
    await tester.pumpAndSettle();

    expect((await repository.load()).captureVisibleText, isTrue);
  });
}
