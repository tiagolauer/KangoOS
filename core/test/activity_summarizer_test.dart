import 'package:drift/drift.dart' show Value;
import 'package:kangoos_core/kangoos_core.dart';
import 'package:test/test.dart';

class _FakeLlmProvider implements LlmProvider {
  _FakeLlmProvider(this.chunks);

  final List<String> chunks;
  List<LlmMessage>? lastMessages;

  @override
  String get id => 'fake';

  @override
  Stream<String> chat(List<LlmMessage> messages) {
    lastMessages = messages;
    return Stream.fromIterable(chunks);
  }
}

class _FailingLlmProvider implements LlmProvider {
  @override
  String get id => 'failing';

  @override
  Stream<String> chat(List<LlmMessage> messages) => Stream.error(Exception('boom'));
}

void main() {
  late KangoosDatabase database;

  setUp(() => database = KangoosDatabase.memory());
  tearDown(() => database.close());

  test('summarize returns noActivity when nothing was captured in the period', () async {
    final summarizer = ActivitySummarizer(database: database);

    final result = await summarizer.summarize(
      provider: _FakeLlmProvider(const ['unused']),
      kind: SummaryKind.periodic,
      start: DateTime.utc(2026, 1, 1),
      end: DateTime.utc(2026, 1, 2),
    );

    expect(result, isA<SummaryFailure>());
    expect((result as SummaryFailure).error, SummaryError.noActivity);
  });

  test('summarize builds a prompt from captured activity and persists the summary', () async {
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'code.exe',
      windowTitle: 'main.dart - KangoOS',
      capturedAt: Value(DateTime.utc(2026, 1, 1, 10)),
    ));
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'chrome.exe',
      windowTitle: 'Drift docs',
      capturedAt: Value(DateTime.utc(2026, 1, 1, 10, 5)),
    ));

    final summarizer = ActivitySummarizer(database: database);
    final provider = _FakeLlmProvider(const ['Worked on ', 'KangoOS.']);

    final result = await summarizer.summarize(
      provider: provider,
      kind: SummaryKind.dayRecap,
      start: DateTime.utc(2026, 1, 1),
      end: DateTime.utc(2026, 1, 2),
    );

    expect(result, isA<SummarySuccess>());
    final summary = (result as SummarySuccess).summary;
    expect(summary.kind, SummaryKind.dayRecap);
    expect(summary.content, 'Worked on KangoOS.');

    final prompt = provider.lastMessages!.single.content;
    expect(prompt, contains('code.exe'));
    expect(prompt, contains('main.dart - KangoOS'));
    expect(prompt, contains('chrome.exe'));

    final stored = await database.watchRecentSummaries().first;
    expect(stored, hasLength(1));
    expect(stored.single.content, 'Worked on KangoOS.');
  });

  test('summarize returns llmFailed when the provider errors', () async {
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'code.exe',
      windowTitle: 'main.dart',
    ));

    final summarizer = ActivitySummarizer(database: database);
    final result = await summarizer.summarize(
      provider: _FailingLlmProvider(),
      kind: SummaryKind.periodic,
      start: DateTime.now().subtract(const Duration(minutes: 1)),
      end: DateTime.now().add(const Duration(minutes: 1)),
    );

    expect(result, isA<SummaryFailure>());
    expect((result as SummaryFailure).error, SummaryError.llmFailed);
    expect(await database.watchRecentSummaries().first, isEmpty);
  });
}
