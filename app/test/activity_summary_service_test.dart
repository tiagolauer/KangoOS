import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kangoos_app/capture/activity_summary_service.dart';
import 'package:kangoos_app/capture/summary_watermark_repository.dart';
import 'package:kangoos_app/secure_credential_store.dart';
import 'package:kangoos_app/settings_repository.dart';

class _FakeSecureCredentialStore implements SecureCredentialStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

class _FakeLlmProvider implements LlmProvider {
  _FakeLlmProvider(this.chunks);

  final List<String> chunks;

  @override
  String get id => 'fake';

  @override
  Stream<String> chat(List<LlmMessage> messages) => Stream.fromIterable(chunks);
}

class _FailingLlmProvider implements LlmProvider {
  @override
  String get id => 'failing';

  @override
  Stream<String> chat(List<LlmMessage> messages) =>
      Stream.error(StateError('llm unreachable'));
}

class _RecordingLlmProvider implements LlmProvider {
  _RecordingLlmProvider(this.prompts);

  final List<String> prompts;

  @override
  String get id => 'recording';

  @override
  Stream<String> chat(List<LlmMessage> messages) {
    prompts.add(messages.map((m) => m.content).join('\n'));
    return Stream.fromIterable(const ['Summary.']);
  }
}

void main() {
  late KangoosDatabase database;
  late SecureCredentialStore secureStore;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = KangoosDatabase.memory();
    secureStore = _FakeSecureCredentialStore();
  });
  tearDown(() => database.close());

  SettingsRepository settingsRepository() =>
      SettingsRepository(secureStore: secureStore);

  Future<void> configureLlm() => settingsRepository().save(
      const LlmSettings(provider: LlmProviderKind.ollama, model: 'llama3'));

  test('tick does nothing when no activity was captured since the last period',
      () async {
    await configureLlm();
    final service = ActivitySummaryService(
      database: database,
      settingsRepository: settingsRepository(),
      providerBuilder: (_) => _FakeLlmProvider(const ['unused']),
    )..start();

    final result = await service.tick();

    expect(result, isNull);
    expect(await database.watchRecentSummaries().first, isEmpty);
  });

  test(
      'tick summarizes activity captured since the last period and persists it',
      () async {
    await configureLlm();
    var clock = DateTime.utc(2026, 1, 1, 10);
    final service = ActivitySummaryService(
      database: database,
      settingsRepository: settingsRepository(),
      providerBuilder: (_) => _FakeLlmProvider(const ['Worked on KangoOS.']),
      now: () => clock,
    )..start();

    clock = clock.add(const Duration(minutes: 5));
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'code.exe',
      windowTitle: 'main.dart',
      capturedAt: Value(clock),
    ));

    clock = clock.add(const Duration(minutes: 15));
    final result = await service.tick();

    expect(result, isA<SummarySuccess>());
    final stored = await database.watchRecentSummaries().first;
    expect(stored, hasLength(1));
    expect(stored.single.kind, SummaryKind.periodic);
    expect(stored.single.content, 'Worked on KangoOS.');
  });

  test('a failed summary keeps its window for the next tick', () async {
    await configureLlm();
    var clock = DateTime.utc(2026, 1, 1, 10);
    final service = ActivitySummaryService(
      database: database,
      settingsRepository: settingsRepository(),
      providerBuilder: (_) => _FailingLlmProvider(),
      now: () => clock,
    );
    await service.start();

    clock = clock.add(const Duration(minutes: 5));
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'code.exe',
      windowTitle: 'main.dart',
      capturedAt: Value(clock),
    ));

    clock = clock.add(const Duration(minutes: 15));
    final failure = await service.tick();
    expect(failure, isA<SummaryFailure>());
    expect(await database.watchRecentSummaries().first, isEmpty);

    final retryPrompts = <String>[];
    final retrying = ActivitySummaryService(
      database: database,
      settingsRepository: settingsRepository(),
      providerBuilder: (_) => _RecordingLlmProvider(retryPrompts),
      now: () => clock,
    );
    await retrying.start();

    clock = clock.add(const Duration(minutes: 20));
    expect(await retrying.tick(), isA<SummarySuccess>());
    expect(retryPrompts.single, contains('main.dart'));
  });

  test('an unconfigured LLM still moves the window forward', () async {
    await settingsRepository().save(const LlmSettings(
        provider: LlmProviderKind.openAi, model: 'gpt-4o', apiKey: ''));
    var clock = DateTime.utc(2026, 1, 1, 10);
    final watermarkRepository = SummaryWatermarkRepository();
    final service = ActivitySummaryService(
      database: database,
      settingsRepository: settingsRepository(),
      watermarkRepository: watermarkRepository,
      providerBuilder: (_) => _FakeLlmProvider(const ['unused']),
      now: () => clock,
    );
    await service.start();

    clock = clock.add(const Duration(minutes: 5));
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'code.exe',
      windowTitle: 'main.dart',
      capturedAt: Value(clock),
    ));

    clock = clock.add(const Duration(minutes: 15));
    expect(await service.tick(), isNull);
    expect((await watermarkRepository.load())!.isAtSameMomentAs(clock), isTrue);
  });

  test('a stale stored watermark is clamped to the catch-up window', () async {
    final clock = DateTime.utc(2026, 1, 2, 10);
    await SummaryWatermarkRepository()
        .save(DateTime.utc(2026, 1, 1, 8));
    await configureLlm();

    final prompts = <String>[];
    final service = ActivitySummaryService(
      database: database,
      settingsRepository: settingsRepository(),
      providerBuilder: (_) => _RecordingLlmProvider(prompts),
      now: () => clock,
    );
    await service.start();

    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'code.exe',
      windowTitle: 'yesterday',
      capturedAt: Value(DateTime.utc(2026, 1, 1, 9)),
    ));
    await database.logActivity(ActivitiesCompanion.insert(
      appName: 'code.exe',
      windowTitle: 'recent',
      capturedAt: Value(clock.subtract(const Duration(minutes: 30))),
    ));

    await service.tick();

    expect(prompts.single, contains('recent'));
    expect(prompts.single, isNot(contains('yesterday')));
  });

  test('tick skips summarizing when no LLM model is configured', () async {
    final service = ActivitySummaryService(
      database: database,
      settingsRepository: settingsRepository(),
      providerBuilder: (_) => _FakeLlmProvider(const ['unused']),
    )..start();

    await database.logActivity(ActivitiesCompanion.insert(
        appName: 'code.exe', windowTitle: 'main.dart'));

    final result = await service.tick();

    expect(result, isNull);
    expect(await database.watchRecentSummaries().first, isEmpty);
  });
}
