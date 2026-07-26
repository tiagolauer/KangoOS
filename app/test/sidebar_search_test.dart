import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';

import 'package:kangoos_app/home/sidebar.dart';

class _CountingEmbeddingProvider implements EmbeddingProvider {
  var calls = 0;

  @override
  String get id => 'counting';

  @override
  Future<List<double>> embed(String text) async {
    calls++;
    return const [1, 0, 0];
  }
}

void main() {
  late KangoosDatabase database;
  late _CountingEmbeddingProvider embeddingProvider;

  setUp(() {
    database = KangoosDatabase.memory();
    embeddingProvider = _CountingEmbeddingProvider();
  });
  tearDown(() => database.close());

  Future<void> pumpSidebar(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Sidebar(
          database: database,
          semanticSearch: SemanticSearch(
              database: database, embeddingProvider: embeddingProvider),
          onSelectSnippet: (_) {},
          onCreateSnippet: () {},
          onGenerateDayRecap: () async =>
              const SummaryFailure(SummaryError.noActivity),
        ),
      ),
    ));
    await tester.pump();
  }

  Future<void> drainStreams(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('typing a query embeds it once, not once per keystroke',
      (tester) async {
    await database.createSnippet(SnippetsCompanion.insert(
        title: 'Kubernetes ingress', content: 'tls termination'));
    await pumpSidebar(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();

    for (final prefix in ['k', 'ku', 'kub', 'kube']) {
      await tester.enterText(find.byType(TextField), prefix);
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(embeddingProvider.calls, 0);

    await tester.pump(searchDebounce);
    await tester.pump(const Duration(milliseconds: 50));

    expect(embeddingProvider.calls, 1);

    await drainStreams(tester);
  });

  testWidgets('a snippet can be copied straight from the list', (tester) async {
    await database.createSnippet(SnippetsCompanion.insert(
        title: 'Reverse a string', content: 'input.reversed'));
    await pumpSidebar(tester);
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byTooltip('Copy snippet'), findsOneWidget);

    await drainStreams(tester);
  });
}
