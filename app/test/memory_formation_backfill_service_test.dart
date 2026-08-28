import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_app/capture/capture_settings_repository.dart';
import 'package:kangoos_app/memory/memory_formation_backfill_service.dart';
import 'package:kangoos_app/secure_credential_store.dart';
import 'package:kangoos_app/settings_repository.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecureStore implements SecureCredentialStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

class _BackfillLlmProvider extends LlmProvider {
  int calls = 0;

  @override
  String get id => 'backfill-test';

  @override
  Stream<String> chat(List<LlmMessage> messages) {
    calls++;
    return Stream.value(
      jsonEncode({
        'summary': 'Memória enriquecida localmente.',
        'confidence': 0.9,
        'decisions': ['Usar memória local'],
        'actionItems': <String>[],
        'technologies': ['Dart'],
        'people': <String>[],
        'projects': ['KangoOS'],
        'files': ['main.dart'],
        'relations': <String>[],
      }),
    );
  }
}

class _BackfillEmbeddingProvider implements EmbeddingProvider {
  int calls = 0;

  @override
  String get id => 'm4-index-test';

  @override
  Future<List<double>> embed(String text) async {
    calls++;
    return const [1, 0, 0];
  }
}

void main() {
  late KangoosDatabase database;
  late SqliteActivityRepository activities;
  late SqliteEpisodeRepository episodes;
  late SettingsRepository settings;
  late CaptureSettingsRepository captureSettings;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = KangoosDatabase.memory();
    activities = SqliteActivityRepository(database);
    episodes = SqliteEpisodeRepository(database);
    settings = SettingsRepository(secureStore: _MemorySecureStore());
    captureSettings = CaptureSettingsRepository();
  });

  tearDown(() => database.close());

  test(
    'backfills and enriches through a configured local LM Studio endpoint',
    () async {
      final clock = DateTime(2026, 8, 26, 12);
      await settings.save(
        const LlmSettings(
          provider: LlmProviderKind.openAi,
          model: 'qwen3',
          baseUrl: 'http://127.0.0.1:1234/v1',
        ),
      );
      await captureSettings.save(const CaptureSettings(retentionDays: 1));
      await activities.create(
        NewActivity(
          appName: 'Code',
          windowTitle: 'main.dart',
          capturedText: 'KangoOS local memory',
          capturedAt: clock.subtract(const Duration(hours: 1)),
        ),
      );
      final provider = _BackfillLlmProvider();
      final service = MemoryFormationBackfillService(
        formation: MemoryFormationService(
          activities: activities,
          episodes: episodes,
        ),
        settingsRepository: settings,
        captureSettingsRepository: captureSettings,
        batchSpan: const Duration(days: 1),
        now: () => clock,
        providerBuilder: (_) => provider,
      );

      final first = await service.tick();
      final second = await service.tick();
      final stored = (await episodes.recent()).single;

      expect(first?.completed, isTrue);
      expect(second?.report.created, 0);
      expect(provider.calls, 1);
      expect(stored.formationStatus, MemoryFormationStatus.enriched);
      expect(stored.formationModelId, contains('127.0.0.1:1234'));
    },
  );

  test('never builds a remote enrichment provider without consent', () async {
    final clock = DateTime(2026, 8, 26, 12);
    await settings.save(
      const LlmSettings(
        provider: LlmProviderKind.openAi,
        model: 'remote-model',
        apiKey: 'stored-secret',
      ),
    );
    await captureSettings.save(const CaptureSettings(retentionDays: 1));
    await activities.create(
      NewActivity(
        appName: 'Code',
        windowTitle: 'private.dart',
        capturedAt: clock.subtract(const Duration(hours: 1)),
      ),
    );
    var providerBuilt = false;
    final service = MemoryFormationBackfillService(
      formation: MemoryFormationService(
        activities: activities,
        episodes: episodes,
      ),
      settingsRepository: settings,
      captureSettingsRepository: captureSettings,
      batchSpan: const Duration(days: 1),
      now: () => clock,
      providerBuilder: (_) {
        providerBuilt = true;
        return _BackfillLlmProvider();
      },
    );

    await service.tick();
    final stored = (await episodes.recent()).single;

    expect(providerBuilt, isFalse);
    expect(stored.formationStatus, MemoryFormationStatus.deterministic);
    expect(stored.formationModelId, isNull);
  });

  test(
    'indexes every pending memory source during the local backfill tick',
    () async {
      final clock = DateTime(2026, 8, 26, 12);
      await settings.save(
        const LlmSettings(
          provider: LlmProviderKind.openAi,
          model: 'qwen3',
          baseUrl: 'http://127.0.0.1:1234/v1',
        ),
      );
      await captureSettings.save(const CaptureSettings(retentionDays: 1));
      await activities.create(
        NewActivity(
          appName: 'Code',
          windowTitle: 'm4.dart',
          capturedText: 'KangoOS unified index',
          capturedAt: clock.subtract(const Duration(hours: 1)),
        ),
      );
      final summaries = SqliteSummaryRepository(database);
      final conversations = SqliteConversationRepository(database);
      final snippets = SqliteSnippetRepository(database);
      await summaries.create(
        NewActivitySummary(
          kind: SummaryKind.daily,
          periodStart: clock.subtract(const Duration(hours: 2)),
          periodEnd: clock,
          content: 'KangoOS unified summary',
        ),
      );
      final conversationId = await conversations.create();
      await conversations.appendMessage(
        conversationId,
        LlmRole.user,
        'KangoOS unified conversation',
      );
      await snippets.create(
        NewSnippet(title: 'KangoOS unified snippet', content: 'M4 index'),
      );
      final embedding = _BackfillEmbeddingProvider();
      final queryEngine = MemoryQueryEngine(
        episodes: episodes,
        summaries: summaries,
        conversations: conversations,
        snippets: snippets,
        activities: activities,
        embeddingProvider: embedding,
      );
      final service = MemoryFormationBackfillService(
        formation: MemoryFormationService(
          activities: activities,
          episodes: episodes,
        ),
        settingsRepository: settings,
        captureSettingsRepository: captureSettings,
        queryEngine: queryEngine,
        batchSpan: const Duration(days: 1),
        now: () => clock,
        providerBuilder: (_) => _BackfillLlmProvider(),
      );

      await service.tick();

      expect(embedding.calls, 4);
      expect(await episodes.vectors(embedding.id), hasLength(1));
      expect(await summaries.vectors(embedding.id), hasLength(1));
      expect(await conversations.vectors(embedding.id), hasLength(1));
      expect(await snippets.vectors(embedding.id), hasLength(1));
    },
  );
}
