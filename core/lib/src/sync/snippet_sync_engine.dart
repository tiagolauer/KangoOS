import 'dart:math';

import '../database/database.dart';
import '../snippets/snippet_repository.dart';
import '../snippets/snippet_service.dart';
import 'sync_transport.dart';

class SyncResult {
  const SyncResult({
    required this.pushed,
    required this.pulled,
    required this.updated,
    this.deletedLocally = 0,
    this.deletedRemotely = 0,
    this.indexingFailures = const {},
  });

  final int pushed;
  final int pulled;
  final int updated;
  final int deletedLocally;
  final int deletedRemotely;
  final Map<int, Object> indexingFailures;
}

class SnippetSyncEngine {
  const SnippetSyncEngine({
    required this.repository,
    required this.transport,
    this.snippetService,
  });

  final SnippetRepository repository;
  final SyncTransport transport;
  final SnippetService? snippetService;

  Future<SyncResult> sync() async {
    final remoteList = await transport.fetchSnippets();
    final remoteTombstoneList = await transport.fetchTombstones();
    final localWithSyncId = <Snippet>[];
    for (final snippet in await repository.all()) {
      if (snippet.syncId != null) {
        localWithSyncId.add(snippet);
        continue;
      }
      final updated = await repository.update(
        snippet.id,
        SnippetUpdate(
          syncId: _generateSyncId(),
          syncIdProvided: true,
          updatedAt: snippet.updatedAt,
        ),
      );
      if (updated != null) localWithSyncId.add(updated);
    }

    final localBySyncId = {for (final s in localWithSyncId) s.syncId!: s};
    final remoteBySyncId = {for (final s in remoteList) s.syncId: s};
    final localTombstones = {
      for (final t in await repository.tombstones()) t.syncId: t.deletedAt,
    };
    final remoteTombstones = {
      for (final t in remoteTombstoneList) t.syncId: t.deletedAt,
    };
    var pushed = 0;
    var pulled = 0;
    var updated = 0;
    var deletedLocally = 0;
    var deletedRemotely = 0;
    final indexingFailures = <int, Object>{};
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
          await repository.delete(local.id);
          deletedLocally++;
        } else {
          await transport.createSnippet(_fromLocal(local));
          pushed++;
        }
        continue;
      }

      if (remote != null && localDeletedAt != null) {
        if (_deletionWins(localDeletedAt, remote.updatedAt)) {
          await transport.deleteSnippet(syncId);
          deletedRemotely++;
        } else {
          await repository.clearTombstone(syncId);
          await _pullCreate(remote, indexingFailures);
          pulled++;
        }
        continue;
      }

      if (local != null && remote == null) {
        if (remoteDeletedAt != null) continue;
        await transport.createSnippet(_fromLocal(local));
        pushed++;
        continue;
      }

      if (remote != null && local == null) {
        if (localDeletedAt != null) continue;
        await _pullCreate(remote, indexingFailures);
        pulled++;
        continue;
      }

      if (local != null && remote != null) {
        if (local.updatedAt.isAfter(remote.updatedAt)) {
          await transport.updateSnippet(remote.remoteId, _fromLocal(local));
          updated++;
        } else if (remote.updatedAt.isAfter(local.updatedAt)) {
          await _pullUpdate(local.id, remote, indexingFailures);
          updated++;
        }
        continue;
      }

      if (localDeletedAt != null && remoteDeletedAt == null) {
        await transport.deleteSnippet(syncId);
        deletedRemotely++;
      }
    }

    return SyncResult(
      pushed: pushed,
      pulled: pulled,
      updated: updated,
      deletedLocally: deletedLocally,
      deletedRemotely: deletedRemotely,
      indexingFailures: indexingFailures,
    );
  }

  Future<void> _pullCreate(
    SyncSnippet remote,
    Map<int, Object> failures,
  ) async {
    final input = NewSnippet(
      title: remote.title,
      content: remote.content,
      language: remote.language,
      tags: remote.tags,
      syncId: remote.syncId,
      createdAt: remote.createdAt,
      updatedAt: remote.updatedAt,
    );
    final service = snippetService;
    if (service == null) {
      await repository.create(input);
      return;
    }
    final result = await service.create(input);
    final error = result.indexingError;
    if (error != null) failures[result.snippet.id] = error;
  }

  Future<void> _pullUpdate(
    int localId,
    SyncSnippet remote,
    Map<int, Object> failures,
  ) async {
    final changes = SnippetUpdate(
      title: remote.title,
      content: remote.content,
      language: remote.language,
      languageProvided: true,
      tags: remote.tags,
      updatedAt: remote.updatedAt,
    );
    final service = snippetService;
    if (service == null) {
      await repository.update(localId, changes);
      return;
    }
    final result = await service.update(localId, changes);
    final error = result?.indexingError;
    if (error != null) failures[localId] = error;
  }

  SyncSnippet _fromLocal(Snippet snippet) => SyncSnippet(
        remoteId: 0,
        title: snippet.title,
        content: snippet.content,
        language: snippet.language,
        tags: snippet.tags,
        syncId: snippet.syncId!,
        createdAt: snippet.createdAt,
        updatedAt: snippet.updatedAt,
      );

  static bool _deletionWins(DateTime deletedAt, DateTime updatedAt) =>
      !deletedAt.isBefore(updatedAt);

  static String _generateSyncId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
