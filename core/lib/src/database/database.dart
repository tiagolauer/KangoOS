import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import '../llm/llm_provider.dart';
import '../memory/memory_deletion.dart';
import 'tables/activities_table.dart';
import 'tables/activity_summaries_table.dart';
import 'tables/conversations_table.dart';
import 'tables/deleted_snippets_table.dart';
import 'tables/memory_episodes_table.dart';
import 'tables/snippets_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Snippets,
    Activities,
    ActivitySummaries,
    Conversations,
    ConversationMessages,
    DeletedSnippets,
    MemoryEpisodes,
  ],
)
class KangoosDatabase extends _$KangoosDatabase {
  KangoosDatabase(super.executor) : databaseFile = null, encryptionKey = null;

  KangoosDatabase.native(File file, {this.encryptionKey})
    : databaseFile = file,
      super(
        NativeDatabase(
          file,
          setup: encryptionKey == null ? null : _setupCipher(encryptionKey),
        ),
      );

  KangoosDatabase.memory()
    : databaseFile = null,
      encryptionKey = null,
      super(NativeDatabase.memory());

  final File? databaseFile;
  final String? encryptionKey;

  static const currentSchemaVersion = 21;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      for (final index in allSchemaEntities.whereType<Index>()) {
        await customStatement('DROP INDEX IF EXISTS ${index.entityName};');
      }
      await m.createAll();
      await _repairLegacySchema(m);
      await _createMemoryEpisodesFts();
      await _createActivitySummariesFts();
      await _createConversationMessagesFts();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(snippets, snippets.embedding);
      }
      if (from < 3) {
        await m.createTable(activities);
      }
      if (from < 4) {
        await m.createTable(activitySummaries);
      }
      if (from < 5) {
        await _createSnippetsFts();
      }
      if (from < 6) {
        await m.addColumn(activities, activities.capturedUrl);
      }
      if (from < 7) {
        await m.createTable(conversations);
        await m.createTable(conversationMessages);
      }
      if (from < 8) {
        await m.addColumn(activities, activities.capturedClipboard);
      }
      if (from < 9) {
        await m.addColumn(snippets, snippets.syncId);
      }
      if (from < 10) {
        await _createActivitiesFts();
      }
      if (from < 11) {
        await m.createTable(deletedSnippets);
      }
      if (from < 12) {
        await _convertEmbeddingsToBinary();
      }
      if (from < 13) {
        await m.addColumn(activities, activities.capturedScreenText);
      }
      if (from < 14) {
        await m.addColumn(activities, activities.capturedAudioText);
      }
      if (from < 15) {
        await _rebuildSnippetsFts();
        await _rebuildActivitiesFts();
      }
      if (from < 16) {
        await m.addColumn(snippets, snippets.embeddingProviderId);
      }
      if (from < 17) {
        await m.createTable(memoryEpisodes);
        await _createMemoryEpisodesFts();
      }
      if (from < 18) {
        await _repairLegacySchema(m);
      }
      if (from < 19 && !await _hasColumn('activities', 'source_id')) {
        await m.addColumn(activities, activities.sourceId);
      }
      if (from < 20) {
        if (!await _hasColumn('memory_episodes', 'id')) {
          await m.createTable(memoryEpisodes);
        } else {
          if (!await _hasColumn('memory_episodes', 'formation_version')) {
            await m.addColumn(memoryEpisodes, memoryEpisodes.formationVersion);
          }
          if (!await _hasColumn('memory_episodes', 'content_hash')) {
            await m.addColumn(memoryEpisodes, memoryEpisodes.contentHash);
          }
          if (!await _hasColumn('memory_episodes', 'formation_status')) {
            await m.addColumn(memoryEpisodes, memoryEpisodes.formationStatus);
          }
          if (!await _hasColumn('memory_episodes', 'confidence')) {
            await m.addColumn(memoryEpisodes, memoryEpisodes.confidence);
          }
          if (!await _hasColumn('memory_episodes', 'decisions')) {
            await m.addColumn(memoryEpisodes, memoryEpisodes.decisions);
          }
          if (!await _hasColumn('memory_episodes', 'action_items')) {
            await m.addColumn(memoryEpisodes, memoryEpisodes.actionItems);
          }
          if (!await _hasColumn('memory_episodes', 'technologies')) {
            await m.addColumn(memoryEpisodes, memoryEpisodes.technologies);
          }
          if (!await _hasColumn('memory_episodes', 'formation_model_id')) {
            await m.addColumn(memoryEpisodes, memoryEpisodes.formationModelId);
          }
        }
        await _rebuildMemoryEpisodesFts();
      }
      if (from < 21) {
        if (await _hasTable('activity_summaries')) {
          if (!await _hasColumn('activity_summaries', 'embedding')) {
            await m.addColumn(activitySummaries, activitySummaries.embedding);
          }
          if (!await _hasColumn(
            'activity_summaries',
            'embedding_provider_id',
          )) {
            await m.addColumn(
              activitySummaries,
              activitySummaries.embeddingProviderId,
            );
          }
          await _rebuildActivitySummariesFts();
        }
        if (await _hasTable('conversation_messages')) {
          if (!await _hasColumn('conversation_messages', 'embedding')) {
            await m.addColumn(
              conversationMessages,
              conversationMessages.embedding,
            );
          }
          if (!await _hasColumn(
            'conversation_messages',
            'embedding_provider_id',
          )) {
            await m.addColumn(
              conversationMessages,
              conversationMessages.embeddingProviderId,
            );
          }
          await _rebuildConversationMessagesFts();
        }
      }
    },
  );

  Future<void> _repairLegacySchema(Migrator migrator) async {
    if (!await _hasColumn('activities', 'captured_url')) {
      await migrator.addColumn(activities, activities.capturedUrl);
    }
    if (!await _hasColumn('activities', 'source_id')) {
      await migrator.addColumn(activities, activities.sourceId);
    }
    if (!await _hasColumn('activities', 'captured_clipboard')) {
      await migrator.addColumn(activities, activities.capturedClipboard);
    }
    if (!await _hasColumn('activities', 'captured_screen_text')) {
      await migrator.addColumn(activities, activities.capturedScreenText);
    }
    if (!await _hasColumn('activities', 'captured_audio_text')) {
      await migrator.addColumn(activities, activities.capturedAudioText);
    }
    if (!await _hasColumn('snippets', 'embedding')) {
      await migrator.addColumn(snippets, snippets.embedding);
    }
    if ((await _columnType('snippets', 'embedding'))?.toUpperCase() == 'TEXT') {
      await _convertEmbeddingsToBinary();
    }
    if (!await _hasColumn('snippets', 'sync_id')) {
      await migrator.addColumn(snippets, snippets.syncId);
    }
    if (!await _hasColumn('snippets', 'embedding_provider_id')) {
      await migrator.addColumn(snippets, snippets.embeddingProviderId);
    }
    await _rebuildSnippetsFts();
    await _rebuildActivitiesFts();
  }

  Future<bool> _hasColumn(String tableName, String columnName) async =>
      await _columnType(tableName, columnName) != null;

  Future<bool> _hasTable(String tableName) async =>
      (await customSelect(
        'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ? LIMIT 1;',
        variables: [
          Variable.withString('table'),
          Variable.withString(tableName),
        ],
      ).getSingleOrNull()) !=
      null;

  Future<String?> _columnType(String tableName, String columnName) async {
    final columns = await customSelect('PRAGMA table_info($tableName);').get();
    for (final column in columns) {
      if (column.read<String>('name') == columnName) {
        return column.read<String>('type');
      }
    }
    return null;
  }

  Future<void> _rebuildSnippetsFts() async {
    for (final name in [
      'snippets_fts_ai',
      'snippets_fts_ad',
      'snippets_fts_au',
    ]) {
      await customStatement('DROP TRIGGER IF EXISTS $name;');
    }
    await customStatement('DROP TABLE IF EXISTS snippets_fts;');
    await _createSnippetsFts();
    await customStatement(
      "INSERT INTO snippets_fts(snippets_fts) VALUES ('rebuild');",
    );
  }

  Future<void> _rebuildActivitiesFts() async {
    for (final name in [
      'activities_fts_ai',
      'activities_fts_ad',
      'activities_fts_au',
    ]) {
      await customStatement('DROP TRIGGER IF EXISTS $name;');
    }
    await customStatement('DROP TABLE IF EXISTS activities_fts;');
    await _createActivitiesFts();
    await customStatement(
      "INSERT INTO activities_fts(activities_fts) VALUES ('rebuild');",
    );
  }

  Future<void> _rebuildMemoryEpisodesFts() async {
    for (final name in [
      'memory_episodes_fts_ai',
      'memory_episodes_fts_ad',
      'memory_episodes_fts_au',
    ]) {
      await customStatement('DROP TRIGGER IF EXISTS $name;');
    }
    await customStatement('DROP TABLE IF EXISTS memory_episodes_fts;');
    await _createMemoryEpisodesFts();
    await customStatement(
      "INSERT INTO memory_episodes_fts(memory_episodes_fts) VALUES ('rebuild');",
    );
  }

  Future<void> _rebuildActivitySummariesFts() async {
    for (final name in [
      'activity_summaries_fts_ai',
      'activity_summaries_fts_ad',
      'activity_summaries_fts_au',
    ]) {
      await customStatement('DROP TRIGGER IF EXISTS $name;');
    }
    await customStatement('DROP TABLE IF EXISTS activity_summaries_fts;');
    await _createActivitySummariesFts();
    await customStatement(
      "INSERT INTO activity_summaries_fts(activity_summaries_fts) VALUES ('rebuild');",
    );
  }

  Future<void> _rebuildConversationMessagesFts() async {
    for (final name in [
      'conversation_messages_fts_ai',
      'conversation_messages_fts_ad',
      'conversation_messages_fts_au',
    ]) {
      await customStatement('DROP TRIGGER IF EXISTS $name;');
    }
    await customStatement('DROP TABLE IF EXISTS conversation_messages_fts;');
    await _createConversationMessagesFts();
    await customStatement(
      "INSERT INTO conversation_messages_fts(conversation_messages_fts) VALUES ('rebuild');",
    );
  }

  Future<void> _convertEmbeddingsToBinary() async {
    await customStatement(
      'ALTER TABLE snippets RENAME COLUMN embedding TO embedding_json;',
    );
    await customStatement('ALTER TABLE snippets ADD COLUMN embedding BLOB;');

    final rows =
        await customSelect(
          'SELECT id, embedding_json FROM snippets WHERE embedding_json IS NOT NULL;',
        ).get();
    for (final row in rows) {
      final vector = const DoubleListConverter().fromSql(
        row.read<String>('embedding_json'),
      );
      await customStatement('UPDATE snippets SET embedding = ? WHERE id = ?;', [
        const EmbeddingConverter().toSql(vector),
        row.read<int>('id'),
      ]);
    }

    await customStatement('ALTER TABLE snippets DROP COLUMN embedding_json;');
  }

  /// External-content FTS5 index over snippets, kept in sync via triggers
  /// (external content mode doesn't auto-sync on writes).
  Future<void> _createSnippetsFts() async {
    await customStatement('''
CREATE VIRTUAL TABLE IF NOT EXISTS snippets_fts USING fts5(
  title, content, tags,
  content='snippets', content_rowid='id'
);
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS snippets_fts_ai AFTER INSERT ON snippets BEGIN
  INSERT INTO snippets_fts(rowid, title, content, tags)
  VALUES (new.id, new.title, new.content, new.tags);
END;
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS snippets_fts_ad AFTER DELETE ON snippets BEGIN
  INSERT INTO snippets_fts(snippets_fts, rowid, title, content, tags)
  VALUES ('delete', old.id, old.title, old.content, old.tags);
END;
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS snippets_fts_au AFTER UPDATE ON snippets BEGIN
  INSERT INTO snippets_fts(snippets_fts, rowid, title, content, tags)
  VALUES ('delete', old.id, old.title, old.content, old.tags);
  INSERT INTO snippets_fts(rowid, title, content, tags)
  VALUES (new.id, new.title, new.content, new.tags);
END;
''');
  }

  Future<void> _createActivitiesFts() async {
    await customStatement('''
CREATE VIRTUAL TABLE IF NOT EXISTS activities_fts USING fts5(
  app_name, window_title, captured_text, captured_url, captured_clipboard,
  captured_screen_text, captured_audio_text,
  content='activities', content_rowid='id'
);
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS activities_fts_ai AFTER INSERT ON activities BEGIN
  INSERT INTO activities_fts(rowid, app_name, window_title, captured_text, captured_url, captured_clipboard, captured_screen_text, captured_audio_text)
  VALUES (new.id, new.app_name, new.window_title, new.captured_text, new.captured_url, new.captured_clipboard, new.captured_screen_text, new.captured_audio_text);
END;
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS activities_fts_ad AFTER DELETE ON activities BEGIN
  INSERT INTO activities_fts(activities_fts, rowid, app_name, window_title, captured_text, captured_url, captured_clipboard, captured_screen_text, captured_audio_text)
  VALUES ('delete', old.id, old.app_name, old.window_title, old.captured_text, old.captured_url, old.captured_clipboard, old.captured_screen_text, old.captured_audio_text);
END;
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS activities_fts_au AFTER UPDATE ON activities BEGIN
  INSERT INTO activities_fts(activities_fts, rowid, app_name, window_title, captured_text, captured_url, captured_clipboard, captured_screen_text, captured_audio_text)
  VALUES ('delete', old.id, old.app_name, old.window_title, old.captured_text, old.captured_url, old.captured_clipboard, old.captured_screen_text, old.captured_audio_text);
  INSERT INTO activities_fts(rowid, app_name, window_title, captured_text, captured_url, captured_clipboard, captured_screen_text, captured_audio_text)
  VALUES (new.id, new.app_name, new.window_title, new.captured_text, new.captured_url, new.captured_clipboard, new.captured_screen_text, new.captured_audio_text);
END;
''');
  }

  Future<int> createSnippet(SnippetsCompanion entry) =>
      into(snippets).insert(entry);

  Future<bool> updateSnippet(Snippet entry) => update(snippets).replace(entry);

  Future<int> deleteSnippet(int id) => transaction(() async {
    final existing = await getSnippetById(id);
    final removed =
        await (delete(snippets)..where((row) => row.id.equals(id))).go();
    final syncId = existing?.syncId;
    if (removed > 0 && syncId != null && syncId.isNotEmpty) {
      await recordSnippetTombstone(syncId);
    }
    return removed;
  });

  Future<void> recordSnippetTombstone(String syncId, {DateTime? deletedAt}) =>
      into(deletedSnippets).insertOnConflictUpdate(
        DeletedSnippetsCompanion(
          syncId: Value(syncId),
          deletedAt:
              deletedAt == null ? const Value.absent() : Value(deletedAt),
        ),
      );

  Future<List<DeletedSnippet>> snippetTombstones() =>
      select(deletedSnippets).get();

  Future<DeletedSnippet?> snippetTombstoneFor(String syncId) =>
      (select(deletedSnippets)
        ..where((row) => row.syncId.equals(syncId))).getSingleOrNull();

  Future<void> clearSnippetTombstone(String syncId) =>
      (delete(deletedSnippets)..where((row) => row.syncId.equals(syncId))).go();

  Future<Snippet?> getSnippetBySyncId(String syncId) =>
      (select(snippets)
        ..where((row) => row.syncId.equals(syncId))).getSingleOrNull();

  Future<Snippet?> getSnippetById(int id) =>
      (select(snippets)..where((row) => row.id.equals(id))).getSingleOrNull();

  Stream<List<Snippet>> watchAllSnippets() =>
      (select(snippets)
        ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])).watch();

  /// Full-text search over title, content and tags, ranked by relevance
  /// (SQLite FTS5's bm25-based `rank`). Tokens are treated as independent
  /// prefix matches (implicit AND), so "reverse str" matches a snippet
  /// containing both "reverse…" and "str…" anywhere, in any order.
  Future<List<Snippet>> searchByKeyword(
    String query, {
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) async {
    final matchQuery = ftsMatchQuery(query);
    if (matchQuery.isEmpty || limit < 1) return const [];

    final sql = StringBuffer(
      'SELECT s.* FROM snippets s '
      'JOIN snippets_fts ON snippets_fts.rowid = s.id '
      'WHERE snippets_fts MATCH ?',
    );
    final variables = <Variable>[Variable.withString(matchQuery)];
    if (start != null) {
      sql.write(' AND s.updated_at >= ?');
      variables.add(Variable.withDateTime(start));
    }
    if (end != null) {
      sql.write(' AND s.created_at < ?');
      variables.add(Variable.withDateTime(end));
    }
    sql.write(' ORDER BY rank LIMIT ?');
    variables.add(Variable.withInt(limit));
    final rows =
        await customSelect(
          sql.toString(),
          variables: variables,
          readsFrom: {snippets},
        ).get();

    return Future.wait(rows.map((row) => Future.value(snippets.map(row.data))));
  }

  Future<List<Snippet>> allSnippets() => select(snippets).get();

  Future<List<Snippet>> snippetsBetween(
    DateTime start,
    DateTime end, {
    int? limit,
  }) {
    final query =
        select(snippets)
          ..where(
            (row) =>
                row.updatedAt.isBiggerOrEqualValue(start) &
                row.createdAt.isSmallerThanValue(end),
          )
          ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Future<List<Snippet>> snippetsWithEmbedding() =>
      (select(snippets)..where((row) => row.embedding.isNotNull())).get();

  Future<List<SnippetVector>> snippetVectors({String? providerId}) async {
    final filter = providerId == null ? '' : ' AND embedding_provider_id = ?';
    final rows =
        await customSelect(
          'SELECT id, embedding, embedding_provider_id FROM snippets '
          'WHERE embedding IS NOT NULL$filter;',
          variables:
              providerId == null ? const [] : [Variable.withString(providerId)],
          readsFrom: {snippets},
        ).get();
    const converter = EmbeddingConverter();
    return rows
        .map(
          (row) => SnippetVector(
            id: row.read<int>('id'),
            embedding: converter.fromSql(row.read<Uint8List>('embedding')),
            providerId: row.read<String?>('embedding_provider_id') ?? '',
          ),
        )
        .toList();
  }

  Future<void> _createMemoryEpisodesFts() async {
    await customStatement('''
CREATE VIRTUAL TABLE IF NOT EXISTS memory_episodes_fts USING fts5(
  title, summary, applications, urls, topics, entities, decisions,
  action_items, technologies,
  content='memory_episodes', content_rowid='id'
);
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS memory_episodes_fts_ai AFTER INSERT ON memory_episodes BEGIN
  INSERT INTO memory_episodes_fts(rowid, title, summary, applications, urls, topics, entities, decisions, action_items, technologies)
  VALUES (new.id, new.title, new.summary, new.applications, new.urls, new.topics, new.entities, new.decisions, new.action_items, new.technologies);
END;
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS memory_episodes_fts_ad AFTER DELETE ON memory_episodes BEGIN
  INSERT INTO memory_episodes_fts(memory_episodes_fts, rowid, title, summary, applications, urls, topics, entities, decisions, action_items, technologies)
  VALUES ('delete', old.id, old.title, old.summary, old.applications, old.urls, old.topics, old.entities, old.decisions, old.action_items, old.technologies);
END;
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS memory_episodes_fts_au AFTER UPDATE ON memory_episodes BEGIN
  INSERT INTO memory_episodes_fts(memory_episodes_fts, rowid, title, summary, applications, urls, topics, entities, decisions, action_items, technologies)
  VALUES ('delete', old.id, old.title, old.summary, old.applications, old.urls, old.topics, old.entities, old.decisions, old.action_items, old.technologies);
  INSERT INTO memory_episodes_fts(rowid, title, summary, applications, urls, topics, entities, decisions, action_items, technologies)
  VALUES (new.id, new.title, new.summary, new.applications, new.urls, new.topics, new.entities, new.decisions, new.action_items, new.technologies);
END;
''');
  }

  Future<void> _createActivitySummariesFts() async {
    await customStatement('''
CREATE VIRTUAL TABLE IF NOT EXISTS activity_summaries_fts USING fts5(
  content,
  content='activity_summaries', content_rowid='id'
);
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS activity_summaries_fts_ai AFTER INSERT ON activity_summaries BEGIN
  INSERT INTO activity_summaries_fts(rowid, content)
  VALUES (new.id, new.content);
END;
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS activity_summaries_fts_ad AFTER DELETE ON activity_summaries BEGIN
  INSERT INTO activity_summaries_fts(activity_summaries_fts, rowid, content)
  VALUES ('delete', old.id, old.content);
END;
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS activity_summaries_fts_au AFTER UPDATE ON activity_summaries BEGIN
  INSERT INTO activity_summaries_fts(activity_summaries_fts, rowid, content)
  VALUES ('delete', old.id, old.content);
  INSERT INTO activity_summaries_fts(rowid, content)
  VALUES (new.id, new.content);
END;
''');
  }

  Future<void> _createConversationMessagesFts() async {
    await customStatement('''
CREATE VIRTUAL TABLE IF NOT EXISTS conversation_messages_fts USING fts5(
  content,
  content='conversation_messages', content_rowid='id'
);
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS conversation_messages_fts_ai AFTER INSERT ON conversation_messages BEGIN
  INSERT INTO conversation_messages_fts(rowid, content)
  VALUES (new.id, new.content);
END;
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS conversation_messages_fts_ad AFTER DELETE ON conversation_messages BEGIN
  INSERT INTO conversation_messages_fts(conversation_messages_fts, rowid, content)
  VALUES ('delete', old.id, old.content);
END;
''');
    await customStatement('''
CREATE TRIGGER IF NOT EXISTS conversation_messages_fts_au AFTER UPDATE ON conversation_messages BEGIN
  INSERT INTO conversation_messages_fts(conversation_messages_fts, rowid, content)
  VALUES ('delete', old.id, old.content);
  INSERT INTO conversation_messages_fts(rowid, content)
  VALUES (new.id, new.content);
END;
''');
  }

  Future<void> setSnippetEmbedding(
    int id,
    List<double> embedding,
    String providerId,
  ) => (update(snippets)..where((row) => row.id.equals(id))).write(
    SnippetsCompanion(
      embedding: Value(embedding),
      embeddingProviderId: Value(providerId),
    ),
  );

  Future<List<Snippet>> snippetsByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final byId = {
      for (final snippet
          in await (select(snippets)..where((row) => row.id.isIn(ids))).get())
        snippet.id: snippet,
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<List<Snippet>> snippetsMissingEmbedding() =>
      (select(snippets)..where((row) => row.embedding.isNull())).get();

  Future<List<Snippet>> snippetsPendingEmbedding(
    String providerId, {
    int? limit,
  }) {
    final query =
        select(snippets)
          ..where(
            (row) =>
                row.embedding.isNull() |
                row.embeddingProviderId.isNull() |
                row.embeddingProviderId.equals(providerId).not(),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.id)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Future<int> logActivity(ActivitiesCompanion entry) =>
      into(activities).insert(entry);

  Future<Activity?> lastActivity() =>
      (select(activities)
            ..orderBy([(row) => OrderingTerm.desc(row.capturedAt)])
            ..limit(1))
          .getSingleOrNull();

  Stream<List<Activity>> watchRecentActivities({int limit = 200}) =>
      (select(activities)
            ..orderBy([(row) => OrderingTerm.desc(row.capturedAt)])
            ..limit(limit))
          .watch();

  Future<List<Activity>> allActivities() => select(activities).get();

  Future<List<Activity>> activitiesByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final found =
        await (select(activities)..where((row) => row.id.isIn(ids))).get();
    final byId = {for (final activity in found) activity.id: activity};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<int> purgeActivitiesOlderThan(DateTime cutoff) =>
      (delete(activities)
        ..where((row) => row.capturedAt.isSmallerThanValue(cutoff))).go();

  Future<List<Activity>> activitiesBetween(
    DateTime start,
    DateTime end, {
    int? limit,
  }) async {
    final query = select(activities)..where(
      (row) =>
          row.capturedAt.isBiggerOrEqualValue(start) &
          row.capturedAt.isSmallerThanValue(end),
    );

    if (limit == null) {
      query.orderBy([(row) => OrderingTerm.asc(row.capturedAt)]);
      return query.get();
    }

    query
      ..orderBy([(row) => OrderingTerm.desc(row.capturedAt)])
      ..limit(limit);
    return (await query.get()).reversed.toList();
  }

  Stream<List<Activity>> watchActivitiesBetween(DateTime start, DateTime end) =>
      (select(activities)
            ..where(
              (row) =>
                  row.capturedAt.isBiggerOrEqualValue(start) &
                  row.capturedAt.isSmallerThanValue(end),
            )
            ..orderBy([(row) => OrderingTerm.asc(row.capturedAt)]))
          .watch();

  Future<List<Activity>> searchActivities(
    String query, {
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) async {
    final matchQuery = ftsMatchQuery(query);
    if (matchQuery.isEmpty) return const [];

    final buffer = StringBuffer(
      'SELECT a.* FROM activities a '
      'JOIN activities_fts ON activities_fts.rowid = a.id '
      'WHERE activities_fts MATCH ?',
    );
    final variables = <Variable>[Variable.withString(matchQuery)];
    if (start != null) {
      buffer.write(' AND a.captured_at >= ?');
      variables.add(Variable.withDateTime(start));
    }
    if (end != null) {
      buffer.write(' AND a.captured_at < ?');
      variables.add(Variable.withDateTime(end));
    }
    buffer.write(' ORDER BY rank LIMIT ?');
    variables.add(Variable.withInt(limit));

    final rows =
        await customSelect(
          buffer.toString(),
          variables: variables,
          readsFrom: {activities},
        ).get();
    return rows.map((row) => activities.map(row.data)).toList();
  }

  Future<int> insertActivitySummary(ActivitySummariesCompanion entry) =>
      into(activitySummaries).insert(entry);

  Future<ActivitySummary?> getSummaryById(int id) =>
      (select(activitySummaries)
        ..where((row) => row.id.equals(id))).getSingleOrNull();

  Future<List<ActivitySummary>> summariesBetween(
    DateTime start,
    DateTime end, {
    int? limit,
  }) {
    final query =
        select(activitySummaries)
          ..where(
            (row) =>
                row.periodEnd.isBiggerThanValue(start) &
                row.periodStart.isSmallerThanValue(end),
          )
          ..orderBy([(row) => OrderingTerm.desc(row.periodEnd)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Stream<List<ActivitySummary>> watchRecentSummaries({int limit = 50}) =>
      (select(activitySummaries)
            ..orderBy([(row) => OrderingTerm.desc(row.periodEnd)])
            ..limit(limit))
          .watch();

  Future<List<ActivitySummary>> allSummaries() =>
      select(activitySummaries).get();

  Future<List<ActivitySummary>> recentSummaries({int limit = 5}) =>
      (select(activitySummaries)
            ..orderBy([(row) => OrderingTerm.desc(row.periodEnd)])
            ..limit(limit))
          .get();

  Future<List<ActivitySummary>> searchActivitySummaries(
    String query, {
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) async {
    final matchQuery = ftsMatchQuery(query);
    if (matchQuery.isEmpty || limit < 1) return const [];
    final sql = StringBuffer(
      'SELECT s.* FROM activity_summaries s '
      'JOIN activity_summaries_fts ON activity_summaries_fts.rowid = s.id '
      'WHERE activity_summaries_fts MATCH ?',
    );
    final variables = <Variable>[Variable.withString(matchQuery)];
    if (start != null) {
      sql.write(' AND s.period_end > ?');
      variables.add(Variable.withDateTime(start));
    }
    if (end != null) {
      sql.write(' AND s.period_start < ?');
      variables.add(Variable.withDateTime(end));
    }
    sql.write(' ORDER BY rank LIMIT ?');
    variables.add(Variable.withInt(limit));
    final rows =
        await customSelect(
          sql.toString(),
          variables: variables,
          readsFrom: {activitySummaries},
        ).get();
    return rows.map((row) => activitySummaries.map(row.data)).toList();
  }

  Future<List<ActivitySummary>> summariesPendingEmbedding(
    String providerId, {
    int? limit,
  }) {
    final query =
        select(activitySummaries)
          ..where(
            (row) =>
                row.embedding.isNull() |
                row.embeddingProviderId.isNull() |
                row.embeddingProviderId.equals(providerId).not(),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.id)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Future<List<ActivitySummaryVector>> activitySummaryVectors(
    String providerId,
  ) async {
    final rows =
        await customSelect(
          'SELECT id, embedding FROM activity_summaries '
          'WHERE embedding IS NOT NULL AND embedding_provider_id = ?;',
          variables: [Variable.withString(providerId)],
          readsFrom: {activitySummaries},
        ).get();
    const converter = EmbeddingConverter();
    return rows
        .map(
          (row) => ActivitySummaryVector(
            id: row.read<int>('id'),
            embedding: converter.fromSql(row.read<Uint8List>('embedding')),
          ),
        )
        .toList();
  }

  Future<void> setActivitySummaryEmbedding(
    int id,
    List<double> embedding,
    String providerId,
  ) => (update(activitySummaries)..where((row) => row.id.equals(id))).write(
    ActivitySummariesCompanion(
      embedding: Value(embedding),
      embeddingProviderId: Value(providerId),
    ),
  );

  Future<List<ActivitySummary>> summariesByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final found =
        await (select(activitySummaries)
          ..where((row) => row.id.isIn(ids))).get();
    final byId = {for (final summary in found) summary.id: summary};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<int> purgeSummariesOlderThan(DateTime cutoff) =>
      (delete(activitySummaries)
        ..where((row) => row.periodEnd.isSmallerOrEqualValue(cutoff))).go();

  Future<int> createConversation() =>
      into(conversations).insert(ConversationsCompanion.insert());

  Future<int?> latestConversationId() async {
    final lastMessage =
        await (select(conversationMessages)
              ..orderBy([(row) => OrderingTerm.desc(row.id)])
              ..limit(1))
            .getSingleOrNull();
    if (lastMessage != null) return lastMessage.conversationId;

    final lastConversation =
        await (select(conversations)
              ..orderBy([(row) => OrderingTerm.desc(row.id)])
              ..limit(1))
            .getSingleOrNull();
    return lastConversation?.id;
  }

  Future<int> appendMessage(int conversationId, LlmRole role, String content) =>
      into(conversationMessages).insert(
        ConversationMessagesCompanion.insert(
          conversationId: conversationId,
          role: role,
          content: content,
        ),
      );

  Future<int> deleteMessage(int id) =>
      (delete(conversationMessages)..where((row) => row.id.equals(id))).go();

  Future<List<ConversationMessage>> messagesForConversation(
    int conversationId,
  ) =>
      (select(conversationMessages)
            ..where((row) => row.conversationId.equals(conversationId))
            ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
          .get();

  Future<List<ConversationMessage>> searchConversationMessages(
    String query, {
    DateTime? start,
    DateTime? end,
    int limit = 20,
  }) async {
    final matchQuery = ftsMatchAnyQuery(query);
    if (matchQuery.isEmpty || limit < 1) return const [];
    final sql = StringBuffer(
      'SELECT m.* FROM conversation_messages m '
      'JOIN conversation_messages_fts ON conversation_messages_fts.rowid = m.id '
      'WHERE conversation_messages_fts MATCH ?',
    );
    final variables = <Variable>[Variable.withString(matchQuery)];
    if (start != null) {
      sql.write(' AND m.created_at >= ?');
      variables.add(Variable.withDateTime(start));
    }
    if (end != null) {
      sql.write(' AND m.created_at < ?');
      variables.add(Variable.withDateTime(end));
    }
    sql.write(' ORDER BY rank, m.created_at DESC LIMIT ?');
    variables.add(Variable.withInt(limit));
    final rows =
        await customSelect(
          sql.toString(),
          variables: variables,
          readsFrom: {conversationMessages},
        ).get();
    return rows.map((row) => conversationMessages.map(row.data)).toList();
  }

  Future<List<ConversationMessage>> conversationMessagesBetween(
    DateTime start,
    DateTime end, {
    int? limit,
  }) {
    final query =
        select(conversationMessages)
          ..where(
            (row) =>
                row.createdAt.isBiggerOrEqualValue(start) &
                row.createdAt.isSmallerThanValue(end),
          )
          ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Future<List<ConversationMessage>> conversationMessagesByIds(
    List<int> ids,
  ) async {
    if (ids.isEmpty) return const [];
    final found =
        await (select(conversationMessages)
          ..where((row) => row.id.isIn(ids))).get();
    final byId = {for (final message in found) message.id: message};
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<List<ConversationMessage>> conversationMessagesPendingEmbedding(
    String providerId, {
    int? limit,
  }) {
    final query =
        select(conversationMessages)
          ..where(
            (row) =>
                row.embedding.isNull() |
                row.embeddingProviderId.isNull() |
                row.embeddingProviderId.equals(providerId).not(),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.id)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Future<List<ConversationMessageVector>> conversationMessageVectors(
    String providerId,
  ) async {
    final rows =
        await customSelect(
          'SELECT id, embedding FROM conversation_messages '
          'WHERE embedding IS NOT NULL AND embedding_provider_id = ?;',
          variables: [Variable.withString(providerId)],
          readsFrom: {conversationMessages},
        ).get();
    const converter = EmbeddingConverter();
    return rows
        .map(
          (row) => ConversationMessageVector(
            id: row.read<int>('id'),
            embedding: converter.fromSql(row.read<Uint8List>('embedding')),
          ),
        )
        .toList();
  }

  Future<void> setConversationMessageEmbedding(
    int id,
    List<double> embedding,
    String providerId,
  ) => (update(conversationMessages)..where((row) => row.id.equals(id))).write(
    ConversationMessagesCompanion(
      embedding: Value(embedding),
      embeddingProviderId: Value(providerId),
    ),
  );

  Stream<List<ConversationSummary>> watchConversationSummaries() {
    return customSelect(
      'SELECT c.id AS id, '
      '(SELECT m.content FROM conversation_messages m '
      "WHERE m.conversation_id = c.id AND m.role = 'user' "
      'ORDER BY m.id ASC LIMIT 1) AS preview, '
      '(SELECT COUNT(*) FROM conversation_messages m '
      'WHERE m.conversation_id = c.id) AS message_count, '
      '(SELECT MAX(m.id) FROM conversation_messages m '
      'WHERE m.conversation_id = c.id) AS last_message_id '
      'FROM conversations c '
      'WHERE message_count > 0 '
      'ORDER BY last_message_id DESC',
      readsFrom: {conversations, conversationMessages},
    ).watch().map(
      (rows) =>
          rows
              .map(
                (row) => ConversationSummary(
                  id: row.read<int>('id'),
                  preview: row.read<String?>('preview') ?? '',
                  messageCount: row.read<int>('message_count'),
                ),
              )
              .toList(),
    );
  }

  Future<void> deleteConversation(int conversationId) => transaction(() async {
    await (delete(conversationMessages)
      ..where((row) => row.conversationId.equals(conversationId))).go();
    await (delete(conversations)
      ..where((row) => row.id.equals(conversationId))).go();
  });

  Future<int> deleteActivity(int id) =>
      (delete(activities)..where((row) => row.id.equals(id))).go();

  Future<int> clearAllActivity() => delete(activities).go();

  Future<int> clearAllSummaries() => delete(activitySummaries).go();

  Future<MemoryDeletionPreview> previewMemoryDeletion(
    MemoryDeletionFilter filter,
  ) async {
    filter.validate();
    return (await _memoryDeletionTargets(filter)).preview;
  }

  Future<MemoryDeletionResult> deleteMemory(MemoryDeletionFilter filter) =>
      transaction(() async {
        filter.validate();
        final targets = await _memoryDeletionTargets(filter);
        final activityIds = targets.activities.map((row) => row.id).toList();
        if (activityIds.isNotEmpty) {
          if (filter.modalities.isEmpty ||
              filter.modalities.contains(MemoryModality.metadata)) {
            for (final ids in _idChunks(activityIds)) {
              await (delete(activities)..where((row) => row.id.isIn(ids))).go();
            }
          } else {
            final values = ActivitiesCompanion(
              capturedText:
                  filter.modalities.contains(MemoryModality.vision)
                      ? const Value(null)
                      : const Value.absent(),
              capturedScreenText:
                  filter.modalities.contains(MemoryModality.vision)
                      ? const Value(null)
                      : const Value.absent(),
              capturedClipboard:
                  filter.modalities.contains(MemoryModality.clipboard)
                      ? const Value(null)
                      : const Value.absent(),
              capturedUrl:
                  filter.modalities.contains(MemoryModality.browser)
                      ? const Value(null)
                      : const Value.absent(),
              capturedAudioText:
                  filter.modalities.contains(MemoryModality.audio)
                      ? const Value(null)
                      : const Value.absent(),
            );
            for (final ids in _idChunks(activityIds)) {
              await (update(activities)
                ..where((row) => row.id.isIn(ids))).write(values);
            }
          }
        }

        for (final ids in _idChunks(
          targets.episodes.map((row) => row.id).toList(),
        )) {
          await (delete(memoryEpisodes)..where((row) => row.id.isIn(ids))).go();
        }
        for (final ids in _idChunks(
          targets.summaries.map((row) => row.id).toList(),
        )) {
          await (delete(activitySummaries)
            ..where((row) => row.id.isIn(ids))).go();
        }
        return MemoryDeletionResult(
          activities: targets.preview.activities,
          episodes: targets.preview.episodes,
          summaries: targets.preview.summaries,
          embeddings: targets.preview.embeddings,
        );
      });

  Future<_MemoryDeletionTargets> _memoryDeletionTargets(
    MemoryDeletionFilter filter,
  ) async {
    final candidates = await _matchingActivities(filter);
    final candidateIds = candidates.map((row) => row.id).toSet();
    final deletesActivities = filter.memoryTypes.contains(MemoryType.activity);
    final deletesEpisodes =
        deletesActivities || filter.memoryTypes.contains(MemoryType.episode);
    final deletesAutomaticSummaries =
        deletesEpisodes ||
        filter.memoryTypes.contains(MemoryType.automaticSummary);

    final episodeQuery = select(memoryEpisodes);
    episodeQuery.where((row) {
      Expression<bool> predicate = const Constant(true);
      if (filter.start != null) {
        predicate &= row.endedAt.isBiggerThanValue(filter.start!);
      }
      if (filter.end != null) {
        predicate &= row.startedAt.isSmallerThanValue(filter.end!);
      }
      return predicate;
    });
    final matchingEpisodes =
        deletesEpisodes
            ? (await episodeQuery.get()).where((episode) {
              if (episode.sourceActivityIds.any(candidateIds.contains)) {
                return true;
              }
              if (episode.sourceActivityIds.isNotEmpty) return false;
              if (filter.activityIds.isNotEmpty) {
                return candidates.any(
                  (activity) =>
                      !activity.capturedAt.isBefore(episode.startedAt) &&
                      activity.capturedAt.isBefore(episode.endedAt),
                );
              }
              return _matchesApplications(episode.applications, filter);
            }).toList()
            : const <MemoryEpisode>[];

    final summaryQuery = select(activitySummaries);
    summaryQuery.where((row) {
      Expression<bool> predicate = const Constant(true);
      if (filter.start != null) {
        predicate &= row.periodEnd.isBiggerThanValue(filter.start!);
      }
      if (filter.end != null) {
        predicate &= row.periodStart.isSmallerThanValue(filter.end!);
      }
      return predicate;
    });
    final matchingSummaries =
        (await summaryQuery.get()).where((summary) {
          final automaticDurable =
              summary.kind == SummaryKind.durable &&
              summary.content.startsWith(automaticDurableMemoryPrefix);
          final selected = switch (summary.kind) {
            SummaryKind.manual => filter.memoryTypes.contains(
              MemoryType.manualSummary,
            ),
            SummaryKind.durable =>
              automaticDurable
                  ? deletesAutomaticSummaries
                  : filter.memoryTypes.contains(MemoryType.durableMemory),
            _ => deletesAutomaticSummaries,
          };
          if (!selected) return false;
          if (summary.kind == SummaryKind.manual ||
              (summary.kind == SummaryKind.durable && !automaticDurable) ||
              (filter.activityIds.isEmpty &&
                  filter.applications.isEmpty &&
                  filter.modalities.isEmpty)) {
            return true;
          }
          if (automaticDurable) {
            final evidenceIds =
                RegExp(r'episódio #(\d+)')
                    .allMatches(summary.content)
                    .map((match) => int.parse(match.group(1)!))
                    .toSet();
            if (evidenceIds.isNotEmpty &&
                matchingEpisodes.any(
                  (episode) => evidenceIds.contains(episode.id),
                )) {
              return true;
            }
          }
          return candidates.any(
            (activity) =>
                !activity.capturedAt.isBefore(summary.periodStart) &&
                activity.capturedAt.isBefore(summary.periodEnd),
          );
        }).toList();

    final affectedActivities =
        deletesActivities ? candidates : const <Activity>[];
    return _MemoryDeletionTargets(
      activities: affectedActivities,
      episodes: matchingEpisodes,
      summaries: matchingSummaries,
    );
  }

  Future<List<Activity>> _matchingActivities(
    MemoryDeletionFilter filter,
  ) async {
    final sql = StringBuffer('SELECT * FROM activities WHERE 1 = 1');
    final variables = <Variable>[];
    if (filter.start != null) {
      sql.write(' AND captured_at >= ?');
      variables.add(Variable.withDateTime(filter.start!));
    }
    if (filter.end != null) {
      sql.write(' AND captured_at < ?');
      variables.add(Variable.withDateTime(filter.end!));
    }
    if (filter.activityIds.isNotEmpty) {
      sql.write(
        ' AND id IN (${List.filled(filter.activityIds.length, '?').join(', ')})',
      );
      variables.addAll(filter.activityIds.map(Variable.withInt));
    }
    final applications =
        filter.applications
            .map((application) => application.trim().toLowerCase())
            .where((application) => application.isNotEmpty)
            .toSet();
    if (applications.isNotEmpty) {
      sql.write(
        ' AND LOWER(app_name) IN (${List.filled(applications.length, '?').join(', ')})',
      );
      variables.addAll(applications.map(Variable.withString));
    }
    if (filter.modalities.isNotEmpty &&
        !filter.modalities.contains(MemoryModality.metadata)) {
      final fields = <String>[];
      if (filter.modalities.contains(MemoryModality.vision)) {
        fields.add("NULLIF(captured_text, '') IS NOT NULL");
        fields.add("NULLIF(captured_screen_text, '') IS NOT NULL");
      }
      if (filter.modalities.contains(MemoryModality.clipboard)) {
        fields.add("NULLIF(captured_clipboard, '') IS NOT NULL");
      }
      if (filter.modalities.contains(MemoryModality.browser)) {
        fields.add("NULLIF(captured_url, '') IS NOT NULL");
      }
      if (filter.modalities.contains(MemoryModality.audio)) {
        fields.add("NULLIF(captured_audio_text, '') IS NOT NULL");
      }
      sql.write(' AND (${fields.join(' OR ')})');
    }
    final rows =
        await customSelect(
          sql.toString(),
          variables: variables,
          readsFrom: {activities},
        ).get();
    return rows.map((row) => activities.map(row.data)).toList();
  }

  static bool _matchesApplications(
    List<String> episodeApplications,
    MemoryDeletionFilter filter,
  ) {
    if (filter.applications.isEmpty) return true;
    final selected =
        filter.applications
            .map((application) => application.trim().toLowerCase())
            .toSet();
    return episodeApplications
        .map((application) => application.toLowerCase())
        .any(selected.contains);
  }

  static Iterable<List<int>> _idChunks(List<int> ids) sync* {
    const chunkSize = 500;
    for (var start = 0; start < ids.length; start += chunkSize) {
      final end =
          start + chunkSize < ids.length ? start + chunkSize : ids.length;
      yield ids.sublist(start, end);
    }
  }

  static final _sqliteMagic = 'SQLite format 3\x00'.codeUnits;

  static bool isPlaintextDatabase(File file) {
    if (!file.existsSync()) return false;
    final handle = file.openSync();
    try {
      final header = handle.readSync(_sqliteMagic.length);
      if (header.length < _sqliteMagic.length) return false;
      for (var i = 0; i < _sqliteMagic.length; i++) {
        if (header[i] != _sqliteMagic[i]) return false;
      }
      return true;
    } finally {
      handle.closeSync();
    }
  }

  static void encryptPlaintextDatabase(File file, String encryptionKey) {
    final escaped = encryptionKey.replaceAll("'", "''");
    final encryptedPath = '${file.path}.encrypting';
    final encrypted = File(encryptedPath);
    if (encrypted.existsSync()) encrypted.deleteSync();

    final db = sqlite3.open(file.path);
    try {
      db.execute(
        "ATTACH DATABASE '$encryptedPath' AS encrypted KEY '$escaped';",
      );
      db.select("SELECT sqlcipher_export('encrypted');");
      db.execute('DETACH DATABASE encrypted;');
    } finally {
      db.dispose();
    }

    removePlaintextBackups(file);
    final backup = File('${file.path}.plaintext-backup');
    file.renameSync(backup.path);
    try {
      encrypted.renameSync(file.path);
      backup.deleteSync();
    } catch (error) {
      if (file.existsSync()) file.deleteSync();
      if (backup.existsSync()) backup.renameSync(file.path);
      if (encrypted.existsSync()) encrypted.deleteSync();
      rethrow;
    }
  }

  static void removePlaintextBackups(File databaseFile) {
    final prefix = '${p.basename(databaseFile.path)}.plaintext-backup';
    if (!databaseFile.parent.existsSync()) return;
    for (final entity in databaseFile.parent.listSync()) {
      final name = p.basename(entity.path);
      if (entity is File && (name == prefix || name.startsWith('$prefix-'))) {
        entity.deleteSync();
      }
    }
  }

  Future<File> createBackup(File destination) {
    final source = databaseFile;
    final key = encryptionKey;
    if (source == null || key == null) {
      throw StateError('Encrypted backups require a file-backed database.');
    }
    return createEncryptedBackup(source, destination, key);
  }

  Future<File> stageRestore(File backup) {
    final target = databaseFile;
    final key = encryptionKey;
    if (target == null || key == null) {
      throw StateError('Encrypted restore requires a file-backed database.');
    }
    return createEncryptedBackup(
      backup,
      File('${target.path}.restore-pending'),
      key,
    );
  }

  static Future<File> createEncryptedBackup(
    File source,
    File destination,
    String encryptionKey,
  ) async {
    if (!source.existsSync()) {
      throw ArgumentError.value(source.path, 'source', 'does not exist');
    }
    final sourcePath = p.canonicalize(source.absolute.path).toLowerCase();
    final destinationPath =
        p.canonicalize(destination.absolute.path).toLowerCase();
    if (sourcePath == destinationPath) {
      throw ArgumentError.value(
        destination.path,
        'destination',
        'must differ from the source database',
      );
    }
    destination.parent.createSync(recursive: true);
    final writing = File('${destination.path}.writing');
    if (writing.existsSync()) writing.deleteSync();

    final sourceDatabase = _openCipherDatabase(source, encryptionKey);
    final destinationDatabase = _openCipherDatabase(writing, encryptionKey);
    try {
      await sourceDatabase.backup(destinationDatabase).drain<void>();
      _verifyIntegrity(destinationDatabase);
    } finally {
      destinationDatabase.dispose();
      sourceDatabase.dispose();
    }

    if (destination.existsSync()) destination.deleteSync();
    writing.renameSync(destination.path);
    return destination;
  }

  static Future<File?> backupBeforeMigration(
    File databaseFile,
    String encryptionKey, {
    Directory? backupDirectory,
  }) async {
    if (!databaseFile.existsSync() || databaseFile.lengthSync() == 0) {
      return null;
    }
    final database = _openCipherDatabase(databaseFile, encryptionKey);
    late final int version;
    try {
      version =
          database.select('PRAGMA user_version;').first.values.first as int;
    } finally {
      database.dispose();
    }
    if (version >= currentSchemaVersion) return null;

    final directory =
        backupDirectory ??
        Directory(p.join(databaseFile.parent.path, 'backups'));
    final destination = File(
      p.join(
        directory.path,
        'kangoos-pre-migration-v$version-to-v$currentSchemaVersion.db',
      ),
    );
    return createEncryptedBackup(databaseFile, destination, encryptionKey);
  }

  static void applyPendingRestore(File databaseFile, String encryptionKey) {
    final pending = File('${databaseFile.path}.restore-pending');
    if (!pending.existsSync()) return;
    final pendingDatabase = _openCipherDatabase(pending, encryptionKey);
    try {
      _verifyIntegrity(pendingDatabase);
    } finally {
      pendingDatabase.dispose();
    }

    final rollback = File('${databaseFile.path}.restore-rollback');
    if (rollback.existsSync()) rollback.deleteSync();
    if (databaseFile.existsSync()) databaseFile.renameSync(rollback.path);
    try {
      pending.renameSync(databaseFile.path);
      for (final suffix in const ['-wal', '-shm']) {
        final sidecar = File('${databaseFile.path}$suffix');
        if (sidecar.existsSync()) sidecar.deleteSync();
      }
      if (rollback.existsSync()) rollback.deleteSync();
    } catch (_) {
      if (databaseFile.existsSync()) databaseFile.deleteSync();
      if (rollback.existsSync()) rollback.renameSync(databaseFile.path);
      rethrow;
    }
  }

  static Database _openCipherDatabase(File file, String encryptionKey) {
    final database = sqlite3.open(file.path);
    try {
      _setupCipher(encryptionKey)(database);
      return database;
    } catch (_) {
      database.dispose();
      rethrow;
    }
  }

  static void _verifyIntegrity(Database database) {
    final result = database.select('PRAGMA integrity_check;');
    if (result.length != 1 || result.first.values.first != 'ok') {
      throw StateError('Database integrity check failed: $result');
    }
  }

  static void Function(Database) _setupCipher(String encryptionKey) {
    return (db) {
      final escaped = encryptionKey.replaceAll("'", "''");
      db.execute("PRAGMA key = '$escaped';");
      if (db.select('PRAGMA cipher_version;').isEmpty) {
        throw StateError(
          'SQLCipher native library not found; refusing to open the '
          'database in plaintext.',
        );
      }
      try {
        db.select('SELECT count(*) FROM sqlite_master;');
      } catch (e) {
        throw StateError(
          'Could not read the database with the given encryption key '
          '(wrong key, or the file is corrupted or not actually '
          'encrypted): $e',
        );
      }
    };
  }
}

class _MemoryDeletionTargets {
  const _MemoryDeletionTargets({
    required this.activities,
    required this.episodes,
    required this.summaries,
  });

  final List<Activity> activities;
  final List<MemoryEpisode> episodes;
  final List<ActivitySummary> summaries;

  MemoryDeletionPreview get preview => MemoryDeletionPreview(
    activities: activities.length,
    episodes: episodes.length,
    summaries: summaries.length,
    embeddings: episodes.where((episode) => episode.embedding != null).length,
  );
}

/// Builds an FTS5 MATCH expression from free-form user input: each word
/// becomes its own quoted-prefix term (implicit AND between terms), so
/// punctuation in the query (":", "-", "(", etc, which FTS5's query syntax
/// would otherwise try to parse as operators) can't produce a syntax error.
String ftsMatchQuery(String query) {
  final tokens = query
      .trim()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty);
  return tokens.map((token) => '"${token.replaceAll('"', '""')}"*').join(' ');
}

String ftsMatchAnyQuery(String query) {
  final tokens = query
      .trim()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty);
  return tokens
      .map((token) => '"${token.replaceAll('"', '""')}"*')
      .join(' OR ');
}
