import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_app/capture/capture_settings_repository.dart';
import 'package:kangoos_app/theme/kangoos_theme.dart';
import 'package:kangoos_app/tray/tray_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('tray panel exposes the main desktop actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(380, 560));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({'capture_paused': true});
    final repository = CaptureSettingsRepository();
    var opened = false;
    var hidden = false;
    var quit = false;

    await tester.pumpWidget(MaterialApp(
      theme: KangoosTheme.dark,
      home: TrayPanel(
        captureSettingsRepository: repository,
        onOpen: () async => opened = true,
        onHide: () async => hidden = true,
        onToggleCapture: () async {
          final current = await repository.load();
          await repository.save(current.copyWith(paused: !current.paused));
        },
        onQuickCapture: () async => true,
        onQuit: () async => quit = true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Captura pausada'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Captura ativa'), findsOneWidget);

    await tester.tap(find.text('Salvar área de transferência'));
    await tester.pumpAndSettle();
    expect(
      find.text('Snippet salvo a partir da área de transferência.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Abrir KangoOS'));
    await tester.tap(find.byTooltip('Fechar painel'));
    await tester.tap(find.byTooltip('Sair do KangoOS'));
    expect(opened, isTrue);
    expect(hidden, isTrue);
    expect(quit, isTrue);
  });
}
