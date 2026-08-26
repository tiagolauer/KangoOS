import 'dart:convert';
import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:test/test.dart';

void main() {
  test('MCP composition exposes structured episodes from its database',
      () async {
    final directory = Directory.systemTemp.createTempSync('kangoos_mcp');
    addTearDown(() => directory.deleteSync(recursive: true));
    final application = await KangoMcpApplication.open({
      databasePathEnvironmentKey: '${directory.path}/kangoos.db',
    });
    addTearDown(application.close);
    await SqliteEpisodeRepository(application.database).create(
      NewMemoryEpisode(
        sourceKey: 'composition-test',
        startedAt: DateTime.utc(2026, 8, 25, 10),
        endedAt: DateTime.utc(2026, 8, 25, 11),
        title: 'Composed memory',
        summary: 'Available through the actual MCP composition root.',
        applications: const ['Code'],
        urls: const [],
        topics: const ['mcp'],
        entities: const [],
        sourceActivityIds: const [1],
      ),
    );

    final result = await application.server.callTool('list_recent_memories');
    final text = ((result['content'] as List).single as Map)['text'] as String;
    final memories = jsonDecode(text) as List;

    expect(memories.single['title'], 'Composed memory');
  });
}
