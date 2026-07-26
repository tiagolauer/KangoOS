import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../llm/llm_provider.dart';
import 'tables/activities_table.dart';
import 'tables/activity_summaries_table.dart';
import 'tables/conversations_table.dart';
import 'tables/snippets_table.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  Snippets,
  Activities,
  ActivitySummaries,
  Conversations,
  ConversationMessages,
])
class KangoosDatabase extends _$KangoosDatabase {
  KangoosDatabase(super.executor);

  KangoosDatabase.native(File file) : super(NativeDatabase(file));

  KangoosDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createSnippetsFts();
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
        },
      );

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

  Future<int> createSnippet(SnippetsCompanion entry) =>
      into(snippets).insert(entry);

  Future<bool> updateSnippet(Snippet entry) => update(snippets).replace(entry);

  Future<int> deleteSnippet(int id) =>
      (delete(snippets)..where((row) => row.id.equals(id))).go();

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

  Future<List<ConversationMessage>> messagesForConversation(int conversationId) =>
      (select(conversationMessages)
            ..where((row) => row.conversationId.equals(conversationId))
            ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
          .get();

  Future<int> deleteActivity(int id) =>
      (delete(activities)..where((row) => row.id.equals(id))).go();

  Future<int> clearAllActivity() => delete(activities).go();

  Future<int> clearAllSummaries() => delete(activitySummaries).go();
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
