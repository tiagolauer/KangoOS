import '../database/database.dart';
import '../database/tables/snippets_table.dart';

class NewSnippet {
  const NewSnippet({
    required this.title,
    required this.content,
    this.language,
    this.tags = const [],
    this.syncId,
    this.createdAt,
    this.updatedAt,
  });

  final String title;
  final String content;
  final String? language;
  final List<String> tags;
  final String? syncId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class SnippetUpdate {
  const SnippetUpdate({
    this.title,
    this.content,
    this.language,
    this.languageProvided = false,
    this.tags,
    this.syncId,
    this.syncIdProvided = false,
    this.updatedAt,
  });

  final String? title;
  final String? content;
  final String? language;
  final bool languageProvided;
  final List<String>? tags;
  final String? syncId;
  final bool syncIdProvided;
  final DateTime? updatedAt;
}

abstract interface class SnippetRepository {
  Future<int> create(NewSnippet snippet);

  Future<Snippet?> update(int id, SnippetUpdate changes);

  Future<int> delete(int id);

  Future<Snippet?> getById(int id);

  Future<Snippet?> getBySyncId(String syncId);

  Stream<List<Snippet>> watchAll();

  Future<List<Snippet>> all();

  Future<List<Snippet>> between(DateTime start, DateTime end, {int? limit});

  Future<List<Snippet>> searchByKeyword(
    String query, {
    DateTime? start,
    DateTime? end,
    int limit = 50,
  });

  Future<List<Snippet>> byIds(List<int> ids);

  Future<List<Snippet>> pendingEmbedding(String providerId, {int? limit});

  Future<List<SnippetVector>> vectors(String providerId);

  Future<void> setEmbedding(int id, List<double> embedding, String providerId);

  Future<void> recordTombstone(String syncId, {DateTime? deletedAt});

  Future<List<DeletedSnippet>> tombstones();

  Future<DeletedSnippet?> tombstoneFor(String syncId);

  Future<void> clearTombstone(String syncId);
}
