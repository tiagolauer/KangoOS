class SyncSnippet {
  const SyncSnippet({
    required this.remoteId,
    required this.title,
    required this.content,
    required this.tags,
    required this.syncId,
    required this.createdAt,
    required this.updatedAt,
    this.language,
  });

  final int remoteId;
  final String title;
  final String content;
  final String? language;
  final List<String> tags;
  final String syncId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class SyncTombstone {
  const SyncTombstone({required this.syncId, required this.deletedAt});

  final String syncId;
  final DateTime deletedAt;
}

class SyncException implements Exception {
  const SyncException(this.message);

  final String message;

  @override
  String toString() => 'SyncException: $message';
}

abstract interface class SyncTransport {
  Future<List<SyncSnippet>> fetchSnippets();

  Future<List<SyncTombstone>> fetchTombstones();

  Future<void> createSnippet(SyncSnippet snippet);

  Future<void> updateSnippet(int remoteId, SyncSnippet snippet);

  Future<void> deleteSnippet(String syncId);
}
