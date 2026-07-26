import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' show Database, sqlite3;

import '../llm/llm_provider.dart';
import 'tables/activities_table.dart';
import 'tables/activity_summaries_table.dart';
import 'tables/conversations_table.dart';
import 'tables/deleted_snippets_table.dart';
import 'tables/snippets_table.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Snippets,
  Activities,
  ActivitySummaries,
  Conversations,
  ConversationMessages,
  DeletedSnippets,
])
class KangoosDatabase extends _$KangoosDatabase {
  KangoosDatabase(super.executor);

  KangoosDatabase.native(File file, {String? encryptionKey})
      : super(NativeDatabase(
          file,
          setup: encryptionKey == null ? null : _setupCipher(encryptionKey),
        ));

  KangoosDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createSnippetsFts();
          await _createActivitiesFts();
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
            await _rebuildActivitiesFts();
          }
        },
      );

  Future<void> _rebuildActivitiesFts() async {
    for (final name in ['activities_fts_ai', 'activities_fts_ad', 'activities_fts_au']) {
      await customStatement('DROP TRIGGER IF EXISTS $name;');
    }
    await customStatement('DROP TABLE IF EXISTS activities_fts;');
    await _createActivitiesFts();
    await customStatement(
        "INSERT INTO activities_fts(activities_fts) VALUES ('rebuild');");
  }

  Future<void> _convertEmbeddingsToBinary() async {
    await customStatement(
        'ALTER TABLE snippets RENAME COLUMN embedding TO embedding_json;');
    await customStatement('ALTER TABLE snippets ADD COLUMN embedding BLOB;');

    final rows = await customSelect(
      'SELECT id, embedding_json FROM snippets WHERE embedding_json IS NOT NULL;',
    ).get();
    for (final row in rows) {
      final vector = const DoubleListConverter()
          .fromSql(row.read<String>('embedding_json'));
      await customStatement(
        'UPDATE snippets SET embedding = ? WHERE id = ?;',
        [const EmbeddingConverter().toSql(vector), row.read<int>('id')],
      );
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
      into(deletedSnippets).insertOnConflictUpdate(DeletedSnippetsCompanion(
        syncId: Value(syncId),
        deletedAt:
            deletedAt == null ? const Value.absent() : Value(deletedAt),
      ));

  Future<List<DeletedSnippet>> snippetTombstones() =>
      select(deletedSnippets).get();

  Future<DeletedSnippet?> snippetTombstoneFor(String syncId) =>
      (select(deletedSnippets)..where((row) => row.syncId.equals(syncId)))
          .getSingleOrNull();

  Future<void> clearSnippetTombstone(String syncId) =>
      (delete(deletedSnippets)..where((row) => row.syncId.equals(syncId))).go();

  Future<Snippet?> getSnippetBySyncId(String syncId) =>
      (select(snippets)..where((row) => row.syncId.equals(syncId)))
          .getSingleOrNull();

  Future<Snippet?> getSnippetById(int id) =>
      (select(snippets)..where((row) => row.id.equals(id))).getSingleOrNull();

  Stream<List<Snippet>> watchAllSnippets() =>
      (select(snippets)..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
          .watch();

  /// Full-text search over title, content and tags, ranked by relevance
  /// (SQLite FTS5's bm25-based `rank`). Tokens are treated as independent
  /// prefix matches (implicit AND), so "reverse str" matches a snippet
  /// containing both "reverse…" and "str…" anywhere, in any order.
  Future<List<Snippet>> searchByKeyword(String query) async {
    final matchQuery = _ftsMatchQuery(query);
    if (matchQuery.isEmpty) return const [];

    final rows = await customSelect(
      'SELECT s.* FROM snippets s '
      'JOIN snippets_fts ON snippets_fts.rowid = s.id '
      'WHERE snippets_fts MATCH ? ORDER BY rank',
      variables: [Variable.withString(matchQuery)],
      readsFrom: {snippets},
    ).get();

    return Future.wait(rows.map((row) => Future.value(snippets.map(row.data))));
  }

  Future<List<Snippet>> allSnippets() => select(snippets).get();

  Future<List<Snippet>> snippetsWithEmbedding() =>
      (select(snippets)..where((row) => row.embedding.isNotNull())).get();

  Future<List<SnippetVector>> snippetVectors() async {
    final rows = await customSelect(
      'SELECT id, embedding FROM snippets WHERE embedding IS NOT NULL;',
      readsFrom: {snippets},
    ).get();
    const converter = EmbeddingConverter();
    return rows
        .map((row) => SnippetVector(
              id: row.read<int>('id'),
              embedding: converter.fromSql(row.read<Uint8List>('embedding')),
            ))
        .toList();
  }

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

  Future<int> logActivity(ActivitiesCompanion entry) =>
      into(activities).insert(entry);

  Future<Activity?> lastActivity() => (select(activities)
        ..orderBy([(row) => OrderingTerm.desc(row.capturedAt)])
        ..limit(1))
      .getSingleOrNull();

  Stream<List<Activity>> watchRecentActivities({int limit = 200}) =>
      (select(activities)
            ..orderBy([(row) => OrderingTerm.desc(row.capturedAt)])
            ..limit(limit))
          .watch();

  Future<List<Activity>> allActivities() => select(activities).get();

  Future<int> purgeActivitiesOlderThan(DateTime cutoff) => (delete(activities)
        ..where((row) => row.capturedAt.isSmallerThanValue(cutoff)))
      .go();

  Future<List<Activity>> activitiesBetween(DateTime start, DateTime end) =>
      (select(activities)
            ..where((row) =>
                row.capturedAt.isBiggerOrEqualValue(start) &
                row.capturedAt.isSmallerThanValue(end))
            ..orderBy([(row) => OrderingTerm.asc(row.capturedAt)]))
          .get();

  Future<List<Activity>> searchActivities(
    String query, {
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) async {
    final matchQuery = _ftsMatchQuery(query);
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

    final rows = await customSelect(
      buffer.toString(),
      variables: variables,
      readsFrom: {activities},
    ).get();
    return rows.map((row) => activities.map(row.data)).toList();
  }

  Future<int> insertActivitySummary(ActivitySummariesCompanion entry) =>
      into(activitySummaries).insert(entry);

  Future<ActivitySummary?> getSummaryById(int id) => (select(activitySummaries)
        ..where((row) => row.id.equals(id)))
      .getSingleOrNull();

  Future<List<ActivitySummary>> summariesBetween(DateTime start, DateTime end) =>
      (select(activitySummaries)
            ..where((row) =>
                row.periodEnd.isBiggerThanValue(start) &
                row.periodStart.isSmallerThanValue(end))
            ..orderBy([(row) => OrderingTerm.asc(row.periodStart)]))
          .get();

  Stream<List<ActivitySummary>> watchRecentSummaries({int limit = 50}) =>
      (select(activitySummaries)
            ..orderBy([(row) => OrderingTerm.desc(row.periodEnd)])
            ..limit(limit))
          .watch();

  Future<List<ActivitySummary>> allSummaries() => select(activitySummaries).get();

  Future<List<ActivitySummary>> recentSummaries({int limit = 5}) =>
      (select(activitySummaries)
            ..orderBy([(row) => OrderingTerm.desc(row.periodEnd)])
            ..limit(limit))
          .get();

  Future<int> createConversation() =>
      into(conversations).insert(ConversationsCompanion.insert());

  Future<int?> latestConversationId() async {
    final lastMessage = await (select(conversationMessages)
          ..orderBy([(row) => OrderingTerm.desc(row.id)])
          ..limit(1))
        .getSingleOrNull();
    if (lastMessage != null) return lastMessage.conversationId;

    final lastConversation = await (select(conversations)
          ..orderBy([(row) => OrderingTerm.desc(row.id)])
          ..limit(1))
        .getSingleOrNull();
    return lastConversation?.id;
  }

  Future<int> appendMessage(int conversationId, LlmRole role, String content) =>
      into(conversationMessages).insert(ConversationMessagesCompanion.insert(
          conversationId: conversationId, role: role, content: content));

  Future<int> deleteMessage(int id) =>
      (delete(conversationMessages)..where((row) => row.id.equals(id))).go();

  Future<List<ConversationMessage>> messagesForConversation(int conversationId) =>
      (select(conversationMessages)
            ..where((row) => row.conversationId.equals(conversationId))
            ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
          .get();

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
    ).watch().map((rows) => rows
        .map((row) => ConversationSummary(
              id: row.read<int>('id'),
              preview: row.read<String?>('preview') ?? '',
              messageCount: row.read<int>('message_count'),
            ))
        .toList());
  }

  Future<void> deleteConversation(int conversationId) => transaction(() async {
        await (delete(conversationMessages)
              ..where((row) => row.conversationId.equals(conversationId)))
            .go();
        await (delete(conversations)..where((row) => row.id.equals(conversationId)))
            .go();
      });

  Future<int> deleteActivity(int id) =>
      (delete(activities)..where((row) => row.id.equals(id))).go();

  Future<int> clearAllActivity() => delete(activities).go();

  Future<int> clearAllSummaries() => delete(activitySummaries).go();

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
      db.execute("ATTACH DATABASE '$encryptedPath' AS encrypted KEY '$escaped';");
      db.select("SELECT sqlcipher_export('encrypted');");
      db.execute('DETACH DATABASE encrypted;');
    } finally {
      db.dispose();
    }

    var backupPath = '${file.path}.plaintext-backup';
    for (var i = 2; File(backupPath).existsSync(); i++) {
      backupPath = '${file.path}.plaintext-backup-$i';
    }
    file.renameSync(backupPath);
    encrypted.renameSync(file.path);
  }

  static void Function(Database) _setupCipher(String encryptionKey) {
    return (db) {
      final escaped = encryptionKey.replaceAll("'", "''");
      db.execute("PRAGMA key = '$escaped';");
      if (db.select('PRAGMA cipher_version;').isEmpty) {
        throw StateError(
            'SQLCipher native library not found; refusing to open the '
            'database in plaintext.');
      }
      try {
        db.select('SELECT count(*) FROM sqlite_master;');
      } catch (e) {
        throw StateError(
            'Could not read the database with the given encryption key '
            '(wrong key, or the file is corrupted or not actually '
            'encrypted): $e');
      }
    };
  }
}

/// Builds an FTS5 MATCH expression from free-form user input: each word
/// becomes its own quoted-prefix term (implicit AND between terms), so
/// punctuation in the query (":", "-", "(", etc, which FTS5's query syntax
/// would otherwise try to parse as operators) can't produce a syntax error.
String _ftsMatchQuery(String query) {
  final tokens =
      query.trim().split(RegExp(r'\s+')).where((token) => token.isNotEmpty);
  return tokens.map((token) => '"${token.replaceAll('"', '""')}"*').join(' ');
}
