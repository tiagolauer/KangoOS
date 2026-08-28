import 'package:kangoos_app/home/timeline_service.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_services.dart';

void main() {
  test('Timeline unifies all M7 item types and supports favorites', () async {
    SharedPreferences.setMockInitialValues({});
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final services = TestServices(database);
    final now = DateTime.now().subtract(const Duration(minutes: 5));
    await services.activities.create(
      NewActivity(
        appName: 'Code',
        windowTitle: 'KangoOS',
        capturedText: 'evento timeline',
        capturedAt: now,
      ),
    );
    await services.episodes.create(
      NewMemoryEpisode(
        sourceKey: 'timeline-episode',
        startedAt: now,
        endedAt: now.add(const Duration(minutes: 1)),
        title: 'Episódio',
        summary: 'episódio timeline',
        applications: const ['Code'],
        urls: const [],
        topics: const ['timeline'],
        entities: const [],
        sourceActivityIds: const [1],
      ),
    );
    await services.summaries.create(
      NewActivitySummary(
        kind: SummaryKind.daily,
        periodStart: now,
        periodEnd: now.add(const Duration(minutes: 1)),
        content: 'resumo timeline',
      ),
    );
    await services.summaries.create(
      NewActivitySummary(
        kind: SummaryKind.manual,
        periodStart: now,
        periodEnd: now.add(const Duration(minutes: 1)),
        content: 'memória manual timeline',
      ),
    );
    final conversationId = await services.conversations.create();
    await services.conversations.appendMessage(
      conversationId,
      LlmRole.assistant,
      'conversa timeline',
    );
    await services.conversations.appendMessage(
      conversationId,
      LlmRole.assistant,
      '$deepStudyMessageMarker\n# DeepStudy: timeline',
    );
    final timeline = TimelineService(
      memory: services.memory,
      conversations: services.conversations,
    );

    final items = await timeline.search(const TimelineQuery());

    expect(
      items.map((item) => item.type).toSet(),
      TimelineItemType.values.toSet(),
    );
    final episode = items.firstWhere(
      (item) => item.type == TimelineItemType.episode,
    );
    expect(await timeline.toggleFavorite(episode), isTrue);
    final favorites = await timeline.search(
      const TimelineQuery(favoritesOnly: true),
    );
    expect(favorites.single.key, episode.key);
  });
}
