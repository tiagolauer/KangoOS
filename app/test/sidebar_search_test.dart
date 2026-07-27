import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';

import 'package:kangoos_app/home/sidebar.dart';

const _pastDebounce = Duration(milliseconds: 400);

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
  late _CountingEmbeddingProvider embeddings;

  setUp(() async {
    database = KangoosDatabase.memory();
    embeddings = _CountingEmbeddingProvider();
    await database.createSnippet(SnippetsCompanion.insert(
      title: 'Kubernetes probes',
      content: 'livenessProbe: ...',
      language: const Value('yaml'),
    ));
  });

  Future<void> pumpSidebar(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Sidebar(
          database: database,
          semanticSearch:
              SemanticSearch(database: database, embeddingProvider: embeddings),
          onSelectSnippet: (_) {},
          onCreateSnippet: () {},
          onGenerateDayRecap: (_) async =>
              const SummaryFailure(SummaryError.noActivity),
        ),
      ),
    ));
    await tester.pump(_pastDebounce);
  }

  Future<void> closeDatabase(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await database.close();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('typing a query runs one semantic search, not one per keystroke',
      (tester) async {
    await pumpSidebar(tester);

    final l10n = AppLocalizations.of(tester.element(find.byType(Sidebar)));
    await tester.tap(find.byTooltip(l10n.switchToSemanticSearch));
    await tester.pump();

    for (final prefix in ['k', 'ku', 'kub', 'kube', 'kuber']) {
      await tester.enterText(find.byType(TextField), prefix);
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.pump(_pastDebounce);
    await tester.pump();

    expect(embeddings.calls, 1);

    await closeDatabase(tester);
  });

  testWidgets('clearing the query goes back to the full snippet list',
      (tester) async {
    await pumpSidebar(tester);

    await tester.enterText(find.byType(TextField), 'nothing matches this');
    await tester.pump(_pastDebounce);
    await tester.pump();
    expect(find.text('Kubernetes probes'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump(_pastDebounce);
    await tester.pump();
    expect(find.text('Kubernetes probes'), findsOneWidget);

    await closeDatabase(tester);
  });
}
