import 'package:drift/drift.dart' show Value;
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:test/test.dart';

void main() {
  late KangoosDatabase database;

  setUp(() => database = KangoosDatabase.memory());
  tearDown(() => database.close());

  Future<int> log(
    String appName,
    String windowTitle, {
    String? text,
    String? url,
    String? clipboard,
    DateTime? at,
  }) =>
      database.logActivity(ActivitiesCompanion.insert(
        appName: appName,
        windowTitle: windowTitle,
        capturedText: Value(text),
        capturedUrl: Value(url),
        capturedClipboard: Value(clipboard),
        capturedAt: at == null ? const Value.absent() : Value(at),
      ));

  test('matches app name, window title, captured text, url and clipboard',
      () async {
    await log('code.exe', 'rag_chat.dart', text: 'refactoring retrieval');
    await log('chrome.exe', 'Drift docs', url: 'https://drift.simonbinder.eu');
    await log('code.exe', 'drift migration notes', text: 'schema bump');
    await log('terminal', 'shell', clipboard: 'git rebase --interactive');

    expect(await database.searchActivities('retrieval'), hasLength(1));
    expect(await database.searchActivities('drift'), hasLength(2));
    expect(await database.searchActivities('rebase'), hasLength(1));
    expect(await database.searchActivities('code.exe'), hasLength(2));
  });

  test('respects a date range', () async {
    await log('a.exe', 'old work on drift', at: DateTime.utc(2026, 1, 1));
    await log('b.exe', 'new work on drift', at: DateTime.utc(2026, 6, 1));

    final results = await database.searchActivities(
      'drift',
      start: DateTime.utc(2026, 5, 1),
      end: DateTime.utc(2026, 7, 1),
    );
    expect(results, hasLength(1));
    expect(results.single.windowTitle, 'new work on drift');
  });

  test('deleting an activity removes it from search', () async {
    final id = await log('a.exe', 'searchable window');
    expect(await database.searchActivities('searchable'), hasLength(1));

    await database.deleteActivity(id);
    expect(await database.searchActivities('searchable'), isEmpty);
  });

  test('blank query returns no results', () async {
    await log('a.exe', 'window');
    expect(await database.searchActivities('   '), isEmpty);
  });

  test('special characters do not throw', () async {
    await log('code.exe', 'std::vector<int>');
    for (final q in ['std::vector', 'a(b)', '-x', 'a:b*c']) {
      await expectLater(database.searchActivities(q), completes);
    }
  });
}
