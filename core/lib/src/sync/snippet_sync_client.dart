import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:http/http.dart' as http;

import '../database/database.dart';

class SyncResult {
  const SyncResult({required this.pushed, required this.pulled, required this.updated});

  final int pushed;
  final int pulled;
  final int updated;
}

class SyncException implements Exception {
  SyncException(this.message);

  final String message;

  @override
  String toString() => 'SyncException: $message';
}

class SnippetSyncClient {
  SnippetSyncClient({
    required this.database,
    required this.baseUrl,
    required this.apiToken,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  final KangoosDatabase database;
  final Uri baseUrl;
  final String apiToken;
  final http.Client httpClient;

  Map<String, String> get _headers => {
        'authorization': 'Bearer $apiToken',
        'content-type': 'application/json',
      };

  Future<SyncResult> sync() async {
    final remoteResponse =
        await httpClient.get(baseUrl.resolve('/snippets'), headers: _headers);
    if (remoteResponse.statusCode != 200) {
      throw SyncException(
          'Failed to fetch remote snippets: ${remoteResponse.statusCode}');
    }
    final remoteList =
        (jsonDecode(remoteResponse.body) as List).cast<Map<String, dynamic>>();

    final localSnippets = await database.allSnippets();
    final localWithSyncId = <Snippet>[];
    for (final snippet in localSnippets) {
      if (snippet.syncId == null) {
        final withSyncId = snippet.copyWith(syncId: Value(_generateSyncId()));
        await database.updateSnippet(withSyncId);
        localWithSyncId.add(withSyncId);
      } else {
        localWithSyncId.add(snippet);
      }
    }

    final localBySyncId = {for (final s in localWithSyncId) s.syncId!: s};
    final remoteBySyncId = {
      for (final r in remoteList)
        if (r['syncId'] != null) r['syncId'] as String: r,
    };

    var pushed = 0;
    var pulled = 0;
    var updated = 0;

    for (final entry in localBySyncId.entries) {
      final remote = remoteBySyncId[entry.key];
      final local = entry.value;
      if (remote == null) {
        await _push(local);
        pushed++;
        continue;
      }
      final remoteUpdatedAt =
          DateTime.fromMillisecondsSinceEpoch(remote['updatedAt'] as int);
      if (local.updatedAt.isAfter(remoteUpdatedAt)) {
        await _pushUpdate(remote['id'] as int, local);
        updated++;
      } else if (remoteUpdatedAt.isAfter(local.updatedAt)) {
        await _pullUpdate(local.id, remote);
        updated++;
      }
    }

    for (final entry in remoteBySyncId.entries) {
      if (!localBySyncId.containsKey(entry.key)) {
        await _pullCreate(entry.value);
        pulled++;
      }
    }

    return SyncResult(pushed: pushed, pulled: pulled, updated: updated);
  }

  Future<void> _push(Snippet local) async {
    final response = await httpClient.post(
      baseUrl.resolve('/snippets'),
      headers: _headers,
      body: jsonEncode({
        'title': local.title,
        'content': local.content,
        'language': local.language,
        'tags': local.tags,
        'syncId': local.syncId,
        'createdAt': local.createdAt.millisecondsSinceEpoch,
        'updatedAt': local.updatedAt.millisecondsSinceEpoch,
      }),
    );
    if (response.statusCode != 200) {
      throw SyncException('Failed to push snippet: ${response.statusCode}');
    }
  }

  Future<void> _pushUpdate(int remoteId, Snippet local) async {
    final response = await httpClient.put(
      baseUrl.resolve('/snippets/$remoteId'),
      headers: _headers,
      body: jsonEncode({
        'title': local.title,
        'content': local.content,
        'language': local.language,
        'tags': local.tags,
        'updatedAt': local.updatedAt.millisecondsSinceEpoch,
      }),
    );
    if (response.statusCode != 200) {
      throw SyncException('Failed to push snippet update: ${response.statusCode}');
    }
  }

  Future<void> _pullCreate(Map<String, dynamic> remote) async {
    await database.createSnippet(SnippetsCompanion.insert(
      title: remote['title'] as String,
      content: remote['content'] as String,
      language: Value(remote['language'] as String?),
      tags: Value((remote['tags'] as List).cast<String>()),
      syncId: Value(remote['syncId'] as String),
      createdAt: Value(DateTime.fromMillisecondsSinceEpoch(remote['createdAt'] as int)),
      updatedAt: Value(DateTime.fromMillisecondsSinceEpoch(remote['updatedAt'] as int)),
    ));
  }

  Future<void> _pullUpdate(int localId, Map<String, dynamic> remote) async {
    final existing = await database.getSnippetById(localId);
    if (existing == null) return;
    await database.updateSnippet(existing.copyWith(
      title: remote['title'] as String,
      content: remote['content'] as String,
      language: Value(remote['language'] as String?),
      tags: (remote['tags'] as List).cast<String>(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(remote['updatedAt'] as int),
    ));
  }

  static String _generateSyncId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
