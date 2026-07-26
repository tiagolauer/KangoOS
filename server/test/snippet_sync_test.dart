import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_server/kangoos_server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

class _FakeEmbeddingProvider implements EmbeddingProvider {
  @override
  String get id => 'fake';

  @override
  Future<List<double>> embed(String text) async => const [1, 0, 0];
}

class _FakeLlmProvider implements LlmProvider {
  @override
  String get id => 'fake';

  @override
  Stream<String> chat(List<LlmMessage> messages) => Stream.fromIterable(['ok']);
}

void main() {
  const apiToken = 'test-token';
  late KangoosDatabase serverDatabase;
  late KangoosDatabase clientDatabase;
  late HttpServer httpServer;
  late Uri baseUrl;
  late SnippetSyncClient syncClient;

  setUp(() async {
    serverDatabase = KangoosDatabase.memory();
    clientDatabase = KangoosDatabase.memory();
    final semanticSearch = SemanticSearch(
        database: serverDatabase, embeddingProvider: _FakeEmbeddingProvider());
    final ragChat =
        RagChat(database: serverDatabase, semanticSearch: semanticSearch);
    final server = KangoosServer(
      database: serverDatabase,
      semanticSearch: semanticSearch,
      ragChat: ragChat,
      llmProvider: _FakeLlmProvider(),
      apiToken: apiToken,
    );
    httpServer = await shelf_io.serve(server.build(), 'localhost', 0);
    baseUrl = Uri.parse('http://localhost:${httpServer.port}');
    syncClient = SnippetSyncClient(
        database: clientDatabase, baseUrl: baseUrl, apiToken: apiToken);
  });

  tearDown(() async {
    await httpServer.close(force: true);
    await serverDatabase.close();
    await clientDatabase.close();
  });

  test('pushes a local-only snippet to the server', () async {
    await clientDatabase.createSnippet(
        SnippetsCompanion.insert(title: 'Local only', content: 'x'));

    final result = await syncClient.sync();

    expect(result.pushed, 1);
    expect(result.pulled, 0);
    final remote = await serverDatabase.allSnippets();
    expect(remote.single.title, 'Local only');
    expect(remote.single.syncId, isNotNull);
  });

  test('pulls a remote-only snippet to the local database', () async {
    await serverDatabase.createSnippet(SnippetsCompanion.insert(
        title: 'Remote only', content: 'y', syncId: const Value('remote-1')));

    final result = await syncClient.sync();

    expect(result.pulled, 1);
    expect(result.pushed, 0);
    final local = await clientDatabase.allSnippets();
    expect(local.single.title, 'Remote only');
    expect(local.single.syncId, 'remote-1');
  });

  test('a newer local edit overwrites an older remote copy', () async {
    await syncClient.sync();
    final id = await clientDatabase
        .createSnippet(SnippetsCompanion.insert(title: 'v1', content: 'x'));
    await syncClient.sync();

    final local = (await clientDatabase.getSnippetById(id))!;
    await clientDatabase.updateSnippet(local.copyWith(
      title: 'v2',
      updatedAt: local.updatedAt.add(const Duration(seconds: 1)),
    ));

    final result = await syncClient.sync();

    expect(result.updated, 1);
    final remote = await serverDatabase.allSnippets();
    expect(remote.single.title, 'v2');
  });

  test('a newer remote edit overwrites an older local copy', () async {
    final id = await clientDatabase
        .createSnippet(SnippetsCompanion.insert(title: 'v1', content: 'x'));
    await syncClient.sync();

    final remoteRow = (await serverDatabase.allSnippets()).single;
    await serverDatabase.updateSnippet(remoteRow.copyWith(
      title: 'v2 from another device',
      updatedAt: remoteRow.updatedAt.add(const Duration(seconds: 1)),
    ));

    final result = await syncClient.sync();

    expect(result.updated, 1);
    final local = (await clientDatabase.getSnippetById(id))!;
    expect(local.title, 'v2 from another device');
  });

  test('re-syncing with nothing new is a no-op', () async {
    await clientDatabase
        .createSnippet(SnippetsCompanion.insert(title: 'a', content: 'b'));
    await syncClient.sync();

    final result = await syncClient.sync();

    expect(result, isA<SyncResult>());
    expect(result.pushed, 0);
    expect(result.pulled, 0);
    expect(result.updated, 0);
    expect(await serverDatabase.allSnippets(), hasLength(1));
    expect(await clientDatabase.allSnippets(), hasLength(1));
  });

  group('delete propagation', () {
    test('a local delete removes the snippet from the server', () async {
      final id = await clientDatabase.createSnippet(
          SnippetsCompanion.insert(title: 'doomed', content: 'x'));
      await syncClient.sync();
      expect(await serverDatabase.allSnippets(), hasLength(1));

      await clientDatabase.deleteSnippet(id);
      final result = await syncClient.sync();

      expect(result.deletedRemotely, 1);
      expect(await serverDatabase.allSnippets(), isEmpty);
    });

    test('a remote delete removes the snippet locally', () async {
      await clientDatabase.createSnippet(
          SnippetsCompanion.insert(title: 'doomed', content: 'x'));
      await syncClient.sync();
      final remote = (await serverDatabase.allSnippets()).single;

      await serverDatabase.deleteSnippet(remote.id);
      final result = await syncClient.sync();

      expect(result.deletedLocally, 1);
      expect(await clientDatabase.allSnippets(), isEmpty);
    });

    test('a delete stays deleted across repeated syncs', () async {
      final id = await clientDatabase.createSnippet(
          SnippetsCompanion.insert(title: 'doomed', content: 'x'));
      await syncClient.sync();
      await clientDatabase.deleteSnippet(id);
      await syncClient.sync();

      final result = await syncClient.sync();

      expect(result.pushed, 0);
      expect(result.pulled, 0);
      expect(await serverDatabase.allSnippets(), isEmpty);
      expect(await clientDatabase.allSnippets(), isEmpty);
    });

    test('an edit newer than the remote delete resurrects the snippet',
        () async {
      final id = await clientDatabase.createSnippet(
          SnippetsCompanion.insert(title: 'contested', content: 'x'));
      await syncClient.sync();
      final remote = (await serverDatabase.allSnippets()).single;
      await serverDatabase.deleteSnippet(remote.id);

      final local = (await clientDatabase.getSnippetById(id))!;
      await clientDatabase.updateSnippet(local.copyWith(
        title: 'edited after the delete',
        updatedAt: DateTime.now().add(const Duration(seconds: 5)),
      ));

      final result = await syncClient.sync();

      expect(result.deletedLocally, 0);
      expect(result.pushed, 1);
      expect((await serverDatabase.allSnippets()).single.title,
          'edited after the delete');
      expect(await clientDatabase.allSnippets(), hasLength(1));
    });

    test('a resurrected snippet is not re-deleted on the next sync', () async {
      final id = await clientDatabase.createSnippet(
          SnippetsCompanion.insert(title: 'contested', content: 'x'));
      await syncClient.sync();
      final remote = (await serverDatabase.allSnippets()).single;
      await serverDatabase.deleteSnippet(remote.id);
      final local = (await clientDatabase.getSnippetById(id))!;
      await clientDatabase.updateSnippet(local.copyWith(
        title: 'edited after the delete',
        updatedAt: DateTime.now().add(const Duration(seconds: 5)),
      ));
      await syncClient.sync();

      await syncClient.sync();

      expect(await serverDatabase.allSnippets(), hasLength(1));
      expect(await clientDatabase.allSnippets(), hasLength(1));
    });

    test('deleting a snippet that was never synced does not touch the server',
        () async {
      final id = await clientDatabase.createSnippet(
          SnippetsCompanion.insert(title: 'never synced', content: 'x'));
      await clientDatabase.deleteSnippet(id);

      final result = await syncClient.sync();

      expect(result.deletedRemotely, 0);
      expect(await serverDatabase.allSnippets(), isEmpty);
    });
  });
}
