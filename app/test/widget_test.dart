import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kangoos_app/capture/capture_settings_repository.dart';
import 'package:kangoos_app/main.dart';

import 'test_services.dart';

class _FakeEmbeddingProvider implements EmbeddingProvider {
  @override
  String get id => 'fake';

  @override
  Future<List<double>> embed(String text) async => const [1, 0, 0];
}

void main() {
  testWidgets('create a snippet and see it in the list', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final database = KangoosDatabase.memory();
    final services = TestServices(
      database,
      embeddingProvider: _FakeEmbeddingProvider(),
    );

    await tester.pumpWidget(
      KangoosApp(
        snippetRepository: services.snippetRepository,
        snippets: services.snippets,
        memory: services.memory,
        conversations: services.conversations,
        captureSettingsRepository: CaptureSettingsRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhum snippet ainda. Toque em + para criar.'),
        findsOneWidget);

    await tester.tap(find.byTooltip('Novo snippet'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Título'),
      'Reverse a string',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Código'),
      'input.split("").reversed.join()',
    );
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('Reverse a string'), findsOneWidget);

    await database.close();
    await tester.pump(const Duration(milliseconds: 200));
  });
}
