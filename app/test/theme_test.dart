import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_app/theme/kangoos_theme.dart';

void main() {
  for (final entry in {
    'dark': KangoosTheme.dark,
    'light': KangoosTheme.light,
  }.entries) {
    testWidgets('${entry.key}: filledTonal icon is not the same color as its '
        'own background', (tester) async {
      final theme = entry.value;
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: IconButton.filledTonal(
            onPressed: () {},
            icon: const Icon(Icons.add),
          ),
        ),
      ));

      final context = tester.element(find.byIcon(Icons.add));
      final iconColor = IconTheme.of(context).color;
      expect(iconColor, isNotNull);
      expect(iconColor, isNot(theme.colorScheme.secondaryContainer));
    });
  }
}
