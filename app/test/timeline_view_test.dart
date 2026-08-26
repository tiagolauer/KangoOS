import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_app/home/timeline_service.dart';
import 'package:kangoos_app/home/timeline_view.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_services.dart';

class _TimelineStub extends TimelineService {
  _TimelineStub({
    required super.memory,
    required super.conversations,
    required this.result,
  });

  final Future<List<TimelineItem>> result;

  @override
  Future<List<TimelineItem>> search(TimelineQuery query) => result;
}

void main() {
  late KangoosDatabase database;
  late TestServices services;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = KangoosDatabase.memory();
    services = TestServices(database);
  });
  tearDown(() => database.close());

  Future<void> pump(WidgetTester tester, Future<List<TimelineItem>> result) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimelineView(
              service: _TimelineStub(
                memory: services.memory,
                conversations: services.conversations,
                result: result,
              ),
              memory: services.memory,
            ),
          ),
        ),
      );

  testWidgets('Timeline exposes a loading state', (tester) async {
    final pending = Completer<List<TimelineItem>>();
    await pump(tester, pending.future);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('Timeline exposes an empty state', (tester) async {
    await pump(tester, Future.value(const []));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nenhum item'), findsOneWidget);
  });

  testWidgets('Timeline exposes an error state and retry action', (
    tester,
  ) async {
    final failed = Completer<List<TimelineItem>>();
    await pump(tester, failed.future);
    failed.completeError(StateError('offline'));
    await tester.pump();
    expect(find.textContaining('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}
