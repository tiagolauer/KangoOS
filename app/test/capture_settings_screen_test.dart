import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kangoos_app/capture/capture_settings_repository.dart';
import 'package:kangoos_app/capture/capture_settings_screen.dart';

void main() {
  late KangoosDatabase database;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = KangoosDatabase.memory();
  });
  tearDown(() => database.close());

  void bumpViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('toggling capture off and adding an excluded app persists',
      (tester) async {
    final repository = CaptureSettingsRepository();
    bumpViewport(tester);

    await tester.pumpWidget(MaterialApp(
      home: CaptureSettingsScreen(repository: repository, database: database),
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
    final repository = CaptureSettingsRepository();
    bumpViewport(tester);

    await tester.pumpWidget(MaterialApp(
      home: CaptureSettingsScreen(repository: repository, database: database),
    ));
    await tester.pumpAndSettle();

    expect((await repository.load()).captureBrowserUrls, isFalse);

    await tester
        .tap(find.widgetWithText(SwitchListTile, 'Capture browser URLs'));
    await tester.pumpAndSettle();

    expect((await repository.load()).captureBrowserUrls, isTrue);
  });

  testWidgets('changing retention persists', (tester) async {
    final repository = CaptureSettingsRepository();
    bumpViewport(tester);

    await tester.pumpWidget(MaterialApp(
      home: CaptureSettingsScreen(repository: repository, database: database),
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
    final repository = CaptureSettingsRepository();
    bumpViewport(tester);

    await tester.pumpWidget(MaterialApp(
      home: CaptureSettingsScreen(repository: repository, database: database),
    ));
    await tester.pumpAndSettle();

    expect((await repository.load()).captureVisibleText, isFalse);

    await tester.tap(find.widgetWithText(
        SwitchListTile, 'Capture visible text (experimental)'));
    await tester.pumpAndSettle();

    expect((await repository.load()).captureVisibleText, isTrue);
  });

  testWidgets(
      'clearing all activity deletes activity and summaries after confirmation',
      (tester) async {
    final repository = CaptureSettingsRepository();
    bumpViewport(tester);

    await database.logActivity(
        ActivitiesCompanion.insert(appName: 'a.exe', windowTitle: 'A'));
    await database.insertActivitySummary(ActivitySummariesCompanion.insert(
      kind: SummaryKind.periodic,
      periodStart: DateTime.now(),
      periodEnd: DateTime.now(),
      content: 'recap',
    ));

    await tester.pumpWidget(MaterialApp(
      home: CaptureSettingsScreen(repository: repository, database: database),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Clear all captured activity'));
    await tester.tap(find.text('Clear all captured activity'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(await database.allActivities(), isEmpty);
    expect(await database.allSummaries(), isEmpty);
    expect(find.textContaining('Cleared'), findsOneWidget);
  });
}
