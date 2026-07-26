import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';

import 'package:kangoos_app/home/chat_home_panel.dart';

void main() {
  late KangoosDatabase database;

  setUp(() => database = KangoosDatabase.memory());
  tearDown(() => database.close());

  Future<int?> pumpSheetAndOpen(WidgetTester tester) async {
    int? popped;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              popped = await showModalBottomSheet<int>(
                context: context,
                builder: (_) => ConversationHistorySheet(
                  database: database,
                  currentConversationId: null,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return popped;
  }

  Future<void> drainStreams(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('lists conversations with their first user message as preview',
      (tester) async {
    final id = await database.createConversation();
    await database.appendMessage(id, LlmRole.user, 'how do I reverse a list?');
    await database.appendMessage(id, LlmRole.assistant, 'use reversed');

    await pumpSheetAndOpen(tester);

    expect(find.text('how do I reverse a list?'), findsOneWidget);
    expect(find.text('2 messages'), findsOneWidget);

    await drainStreams(tester);
  });

  testWidgets('deleting a conversation removes it from the list', (tester) async {
    final id = await database.createConversation();
    await database.appendMessage(id, LlmRole.user, 'delete me');

    await pumpSheetAndOpen(tester);
    expect(find.text('delete me'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Delete this conversation?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('delete me'), findsNothing);
    expect(find.text('No saved conversations yet.'), findsOneWidget);

    await drainStreams(tester);
  });

  testWidgets('tapping a conversation pops the sheet with its id',
      (tester) async {
    final id = await database.createConversation();
    await database.appendMessage(id, LlmRole.user, 'pick me');

    int? popped;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              popped = await showModalBottomSheet<int>(
                context: context,
                builder: (_) => ConversationHistorySheet(
                  database: database,
                  currentConversationId: null,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('pick me'));
    await tester.pumpAndSettle();

    expect(popped, id);

    await drainStreams(tester);
  });
}
