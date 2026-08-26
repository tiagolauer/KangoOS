import 'package:drift/drift.dart' show Value;

import '../../database/database.dart';
import '../../database/tables/snippets_table.dart';
import '../../snippets/snippet_repository.dart';

class SqliteSnippetRepository implements SnippetRepository {
  const SqliteSnippetRepository(this.database);

  final KangoosDatabase database;

  @override
  Future<int> create(NewSnippet snippet) => database.createSnippet(
        SnippetsCompanion.insert(
          title: snippet.title,
          content: snippet.content,
          language: Value(snippet.language),
          tags: Value(snippet.tags),
          syncId: Value(snippet.syncId),
          createdAt: snippet.createdAt == null
              ? const Value.absent()
              : Value(snippet.createdAt!),
          updatedAt: snippet.updatedAt == null
              ? const Value.absent()
              : Value(snippet.updatedAt!),
        ),
      );

  @override
  Future<Snippet?> update(int id, SnippetUpdate changes) async {
    final existing = await database.getSnippetById(id);
    if (existing == null) return null;
    final contentChanged =
        (changes.title != null && changes.title != existing.title) ||
            (changes.content != null && changes.content != existing.content);
    final updated = existing.copyWith(
      title: changes.title ?? existing.title,
      content: changes.content ?? existing.content,
      language: changes.languageProvided
          ? Value(changes.language)
          : Value(existing.language),
      tags: changes.tags ?? existing.tags,
      syncId: changes.syncIdProvided
          ? Value(changes.syncId)
          : Value(existing.syncId),
      embedding: contentChanged ? const Value(null) : Value(existing.embedding),
      embeddingProviderId: contentChanged
          ? const Value(null)
          : Value(existing.embeddingProviderId),
      updatedAt: changes.updatedAt ?? existing.updatedAt,
    );
    await database.updateSnippet(updated);
    return updated;
  }

  @override
  Future<int> delete(int id) => database.deleteSnippet(id);

  @override
  Future<Snippet?> getById(int id) => database.getSnippetById(id);

  @override
  Future<Snippet?> getBySyncId(String syncId) =>
      database.getSnippetBySyncId(syncId);

  @override
  Stream<List<Snippet>> watchAll() => database.watchAllSnippets();

  @override
  Future<List<Snippet>> all() => database.allSnippets();

  @override
  Future<List<Snippet>> searchByKeyword(String query) =>
      database.searchByKeyword(query);

  @override
  Future<List<Snippet>> byIds(List<int> ids) => database.snippetsByIds(ids);

  @override
  Future<List<Snippet>> pendingEmbedding(String providerId) =>
      database.snippetsPendingEmbedding(providerId);

  @override
  Future<List<SnippetVector>> vectors(String providerId) =>
      database.snippetVectors(providerId: providerId);

  @override
  Future<void> setEmbedding(
    int id,
    List<double> embedding,
    String providerId,
  ) =>
      database.setSnippetEmbedding(id, embedding, providerId);

  @override
  Future<void> recordTombstone(String syncId, {DateTime? deletedAt}) =>
      database.recordSnippetTombstone(syncId, deletedAt: deletedAt);

  @override
  Future<List<DeletedSnippet>> tombstones() => database.snippetTombstones();

  @override
  Future<DeletedSnippet?> tombstoneFor(String syncId) =>
      database.snippetTombstoneFor(syncId);

  @override
  Future<void> clearTombstone(String syncId) =>
      database.clearSnippetTombstone(syncId);
}
