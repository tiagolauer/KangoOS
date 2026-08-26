import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_app/capture/capture_status.dart';
import 'package:kangoos_app/capture/capture_status_indicator.dart';

void main() {
  testWidgets('shows persistent microphone and OCR indicators while active',
      (tester) async {
    final controller = CaptureStatusController();
    addTearDown(controller.dispose);
    controller.setMicrophoneActive(true);
    controller.setOcrActive(true);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('pt'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CaptureStatusIndicator(controller: controller),
      ),
    ));

    expect(find.text('Microfone em captura'), findsOneWidget);
    expect(find.text('OCR da janela ativo'), findsOneWidget);
  });
}
