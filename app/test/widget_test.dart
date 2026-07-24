import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';

import 'package:kangoos_app/main.dart';

void main() {
  testWidgets('create a snippet and see it in the list', (tester) async {
    final database = KangoosDatabase.memory();

    await tester.pumpWidget(KangoosApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('No snippets yet. Tap + to add one.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Reverse a string',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Code'),
      'input.split("").reversed.join()',
    );
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('Reverse a string'), findsOneWidget);

    await database.close();
    await tester.pump(const Duration(milliseconds: 200));
  });
}
