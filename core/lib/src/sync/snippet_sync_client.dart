import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:http/http.dart' as http;

import '../database/database.dart';

class SyncResult {
  const SyncResult({
    required this.pushed,
    required this.pulled,
    required this.updated,
    this.deletedLocally = 0,
    this.deletedRemotely = 0,
  });

  final int pushed;
  final int pulled;
  final int updated;
  final int deletedLocally;
  final int deletedRemotely;
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
    final remoteList = await _fetchRemoteSnippets();
    final remoteTombstones = await _fetchRemoteTombstones();

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
    final localTombstones = {
      for (final t in await database.snippetTombstones()) t.syncId: t.deletedAt,
    };

    var pushed = 0;
    var pulled = 0;
    var updated = 0;
    var deletedLocally = 0;
    var deletedRemotely = 0;

    final allSyncIds = <String>{
      ...localBySyncId.keys,
      ...remoteBySyncId.keys,
      ...localTombstones.keys,
      ...remoteTombstones.keys,
    };

    for (final syncId in allSyncIds) {
      final local = localBySyncId[syncId];
      final remote = remoteBySyncId[syncId];
      final localDeletedAt = localTombstones[syncId];
      final remoteDeletedAt = remoteTombstones[syncId];

      if (local != null && remoteDeletedAt != null) {
        if (_deletionWins(remoteDeletedAt, local.updatedAt)) {
          await database.deleteSnippet(local.id);
          deletedLocally++;
        } else {
          await _push(local);
          pushed++;
        }
        continue;
      }

      if (remote != null && localDeletedAt != null) {
        final remoteUpdatedAt =
            DateTime.fromMillisecondsSinceEpoch(remote['updatedAt'] as int);
        if (_deletionWins(localDeletedAt, remoteUpdatedAt)) {
          await _deleteRemote(syncId);
          deletedRemotely++;
        } else {
          await database.clearSnippetTombstone(syncId);
          await _pullCreate(remote);
          pulled++;
        }
        continue;
      }

      if (local != null && remote == null) {
        if (remoteDeletedAt != null) continue;
        await _push(local);
        pushed++;
        continue;
      }

      if (remote != null && local == null) {
        if (localDeletedAt != null) continue;
        await _pullCreate(remote);
        pulled++;
        continue;
      }

      if (local != null && remote != null) {
        final remoteUpdatedAt =
            DateTime.fromMillisecondsSinceEpoch(remote['updatedAt'] as int);
        if (local.updatedAt.isAfter(remoteUpdatedAt)) {
          await _pushUpdate(remote['id'] as int, local);
          updated++;
        } else if (remoteUpdatedAt.isAfter(local.updatedAt)) {
          await _pullUpdate(local.id, remote);
          updated++;
        }
        continue;
      }

      if (localDeletedAt != null && remoteDeletedAt == null) {
        await _deleteRemote(syncId);
        deletedRemotely++;
      }
    }

    return SyncResult(
      pushed: pushed,
      pulled: pulled,
      updated: updated,
      deletedLocally: deletedLocally,
      deletedRemotely: deletedRemotely,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRemoteSnippets() async {
    final response =
        await httpClient.get(baseUrl.resolve('/snippets'), headers: _headers);
    if (response.statusCode != 200) {
      throw SyncException(
          'Failed to fetch remote snippets: ${response.statusCode}');
    }
    return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, DateTime>> _fetchRemoteTombstones() async {
    final response = await httpClient.get(
        baseUrl.resolve('/snippets/deleted'),
        headers: _headers);
    if (response.statusCode == 404) return const {};
    if (response.statusCode != 200) {
      throw SyncException(
          'Failed to fetch remote deletions: ${response.statusCode}');
    }
    final list = (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    return {
      for (final t in list)
        t['syncId'] as String:
            DateTime.fromMillisecondsSinceEpoch(t['deletedAt'] as int),
    };
  }

  Future<void> _deleteRemote(String syncId) async {
    final response = await httpClient.delete(
      baseUrl.resolve('/snippets/by-sync-id/$syncId'),
      headers: _headers,
    );
    if (response.statusCode != 204 && response.statusCode != 404) {
      throw SyncException(
          'Failed to delete remote snippet: ${response.statusCode}');
    }
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

  static bool _deletionWins(DateTime deletedAt, DateTime updatedAt) =>
      !deletedAt.isBefore(updatedAt);

  static String _generateSyncId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
