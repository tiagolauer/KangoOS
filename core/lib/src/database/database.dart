import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'tables/activities_table.dart';
import 'tables/snippets_table.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Snippets, Activities])
class KangoosDatabase extends _$KangoosDatabase {
  KangoosDatabase(super.executor);

  KangoosDatabase.native(File file) : super(NativeDatabase(file));

  KangoosDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(snippets, snippets.embedding);
          }
          if (from < 3) {
            await m.createTable(activities);
          }
        },
      );

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

  Future<List<Snippet>> searchByKeyword(String query) {
    final pattern = '%$query%';
    return (select(snippets)
          ..where((row) => row.title.like(pattern) | row.content.like(pattern)))
        .get();
  }

  Future<List<Snippet>> allSnippets() => select(snippets).get();

  Future<List<Snippet>> snippetsWithEmbedding() =>
      (select(snippets)..where((row) => row.embedding.isNotNull())).get();

  Future<List<Snippet>> snippetsMissingEmbedding() =>
      (select(snippets)..where((row) => row.embedding.isNull())).get();

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

  Future<int> purgeActivitiesOlderThan(DateTime cutoff) =>
      (delete(activities)..where((row) => row.capturedAt.isSmallerThanValue(cutoff))).go();
}
