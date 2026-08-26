import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kangoos_app/capture/capture_settings_repository.dart';
import 'package:kangoos_app/capture/capture_settings_screen.dart';
import 'package:kangoos_app/capture/capture_source_registry.dart';
import 'package:kangoos_app/capture/window_snapshot.dart';

import 'test_services.dart';

void main() {
  late KangoosDatabase database;
  late TestServices services;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = KangoosDatabase.memory();
    services = TestServices(database);
  });
  tearDown(() => database.close());

  void bumpViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('toggling capture off and adding an excluded app persists', (
    tester,
  ) async {
    final repository = CaptureSettingsRepository();
    bumpViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CaptureSettingsScreen(
          repository: repository,
          memory: services.memory,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Capture active window'),
    );
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

  testWidgets('toggling optional capture and redaction settings persists', (
    tester,
  ) async {
    final repository = CaptureSettingsRepository();
    bumpViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CaptureSettingsScreen(
          repository: repository,
          memory: services.memory,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect((await repository.load()).captureBrowserUrls, isFalse);

    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Capture browser URLs'),
    );
    await tester.pumpAndSettle();

    expect((await repository.load()).captureBrowserUrls, isTrue);

    await tester.ensureVisible(
      find.widgetWithText(SwitchListTile, 'Redact personal data'),
    );
    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Redact personal data'),
    );
    await tester.pumpAndSettle();

    expect((await repository.load()).redactPii, isTrue);
  });

  testWidgets('changing retention persists', (tester) async {
    final repository = CaptureSettingsRepository();
    bumpViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CaptureSettingsScreen(
          repository: repository,
          memory: services.memory,
        ),
      ),
    );
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

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CaptureSettingsScreen(
          repository: repository,
          memory: services.memory,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect((await repository.load()).captureVisibleText, isFalse);

    await tester.tap(
      find.widgetWithText(
        SwitchListTile,
        'Capture visible text (experimental)',
      ),
    );
    await tester.pumpAndSettle();

    expect((await repository.load()).captureVisibleText, isTrue);
  });

  testWidgets('timed pause persists and can be resumed immediately', (
    tester,
  ) async {
    final repository = CaptureSettingsRepository();
    bumpViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CaptureSettingsScreen(
          repository: repository,
          memory: services.memory,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('15 minutes'));
    await tester.pumpAndSettle();
    final paused = await repository.load();
    expect(paused.paused, isTrue);
    expect(paused.resumeAt, isNotNull);

    await tester.tap(find.text('Resume now'));
    await tester.pumpAndSettle();
    final resumed = await repository.load();
    expect(resumed.paused, isFalse);
    expect(resumed.resumeAt, isNull);
  });

  testWidgets('known sources require an explicit per-source opt-in', (
    tester,
  ) async {
    final repository = CaptureSettingsRepository();
    final sources = CaptureSourceRegistry();
    await sources.observe(
      const WindowSnapshot(
        appId: 'windows:c:/example.exe',
        appName: 'Example app',
        windowTitle: 'Example',
      ),
    );
    bumpViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CaptureSettingsScreen(
          repository: repository,
          memory: services.memory,
          sourceRegistry: sources,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sourceCard = find.ancestor(
      of: find.text('Example app'),
      matching: find.byType(Card),
    );
    final sourceSwitch = find.descendant(
      of: sourceCard,
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(sourceSwitch).value, isFalse);

    await tester.tap(sourceSwitch);
    await tester.pumpAndSettle();

    final source = (await sources.list()).single;
    expect(source.enabled, isTrue);
  });

  testWidgets(
    'clearing all activity deletes activity and summaries after confirmation',
    (tester) async {
      final repository = CaptureSettingsRepository();
      bumpViewport(tester);

      await database.logActivity(
        ActivitiesCompanion.insert(appName: 'a.exe', windowTitle: 'A'),
      );
      await database.insertActivitySummary(
        ActivitySummariesCompanion.insert(
          kind: SummaryKind.periodic,
          periodStart: DateTime.now(),
          periodEnd: DateTime.now(),
          content: 'recap',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CaptureSettingsScreen(
            repository: repository,
            memory: services.memory,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Clear all captured activity'));
      await tester.tap(find.text('Clear all captured activity'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(await database.allActivities(), isEmpty);
      expect(await database.allSummaries(), isEmpty);
      expect(find.textContaining('Cleared'), findsOneWidget);
    },
  );
}
