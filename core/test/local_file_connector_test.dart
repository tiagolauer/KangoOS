import 'dart:io';

import 'package:kangoos_core/src/connectors/agent_connector.dart';
import 'package:kangoos_core/src/connectors/local_file_connector.dart';
import 'package:kangoos_core/src/llm/llm_stream.dart';
import 'package:test/test.dart';

void main() {
  late Directory sandbox;
  late Directory root;
  late File outside;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('kangoos-file-connector-');
    root =
        await Directory(
          '${sandbox.path}${Platform.pathSeparator}allowed',
        ).create();
    outside = await File(
      '${sandbox.path}${Platform.pathSeparator}outside.txt',
    ).writeAsString('fora da allowlist');
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('searches only allowed roots by file name and text content', () async {
    await File(
      '${root.path}${Platform.pathSeparator}meeting.txt',
    ).writeAsString('Plano completo do KangoOS M6.');
    final nested =
        await Directory('${root.path}${Platform.pathSeparator}notes').create();
    await File(
      '${nested.path}${Platform.pathSeparator}release.md',
    ).writeAsString('Checklist sem o termo da primeira busca.');
    final connector = _connector(root);
    final registry = AgentConnectorRegistry(connector.tools);

    final contentResult = await registry.execute(searchLocalFilesToolName, {
      'query': 'kangoos',
    }, _context());
    final contentMatches = _matches(contentResult);
    expect(contentMatches, hasLength(1));
    expect(contentMatches.single['path'], 'meeting.txt');
    expect(contentResult.evidence.single.content, contains('KangoOS'));
    expect(contentResult.evidence.single.toJson()['untrusted'], isTrue);
    expect(
      contentResult.evidence.single.uri!.toFilePath(),
      isNot(outside.path),
    );

    final nameResult = await registry.execute(searchLocalFilesToolName, {
      'query': 'release',
    }, _context());
    expect(_matches(nameResult).single['path'], 'notes/release.md');
  });

  test(
    'reads relative paths and rejects traversal, absolute paths and ADS',
    () async {
      await File(
        '${root.path}${Platform.pathSeparator}plain.txt',
      ).writeAsString('conteúdo permitido');
      final registry = AgentConnectorRegistry(_connector(root).tools);

      final result = await registry.execute(readLocalFileToolName, {
        'rootId': 'docs',
        'path': 'plain.txt',
      }, _context());
      expect(result.evidence.single.content, 'conteúdo permitido');
      expect((result.data! as Map<String, Object?>)['rootId'], 'docs');

      for (final path in ['../outside.txt', outside.absolute.path]) {
        await expectLater(
          registry.execute(readLocalFileToolName, {
            'rootId': 'docs',
            'path': path,
          }, _context()),
          throwsA(isA<LocalFileAccessException>()),
        );
      }
      if (Platform.isWindows) {
        await expectLater(
          registry.execute(readLocalFileToolName, {
            'rootId': 'docs',
            'path': 'plain.txt:secret',
          }, _context()),
          throwsA(isA<LocalFileAccessException>()),
        );
      }
    },
  );

  test('rejects symbolic links that point outside the root', () async {
    final link = Link('${root.path}${Platform.pathSeparator}escape.txt');
    try {
      await link.create(outside.path);
    } on FileSystemException {
      markTestSkipped('This host does not permit creating symbolic links.');
      return;
    }
    final registry = AgentConnectorRegistry(_connector(root).tools);

    await expectLater(
      registry.execute(readLocalFileToolName, {
        'rootId': 'docs',
        'path': 'escape.txt',
      }, _context()),
      throwsA(isA<LocalFileAccessException>()),
    );
  });

  test('enforces size and text-only limits', () async {
    await File(
      '${root.path}${Platform.pathSeparator}large.txt',
    ).writeAsBytes(List<int>.filled(maxLocalFileBytes + 1, 65));
    await File(
      '${root.path}${Platform.pathSeparator}binary.dat',
    ).writeAsBytes([0x89, 0x50, 0x4e, 0x47, 0]);
    await File(
      '${root.path}${Platform.pathSeparator}invalid.txt',
    ).writeAsBytes([0xc3, 0x28]);
    await File(
      '${root.path}${Platform.pathSeparator}control.dat',
    ).writeAsBytes([1, 2, 3]);
    final registry = AgentConnectorRegistry(_connector(root).tools);

    await expectLater(
      registry.execute(readLocalFileToolName, {
        'rootId': 'docs',
        'path': 'large.txt',
      }, _context()),
      throwsA(isA<LocalFileTooLargeException>()),
    );
    for (final path in ['binary.dat', 'invalid.txt', 'control.dat']) {
      await expectLater(
        registry.execute(readLocalFileToolName, {
          'rootId': 'docs',
          'path': path,
        }, _context()),
        throwsA(isA<LocalFileBinaryException>()),
      );
    }

    final search = await registry.execute(searchLocalFilesToolName, {
      'query': 'missing',
    }, _context());
    final data = search.data! as Map<String, Object?>;
    expect(data['skippedLarge'], 1);
    expect(data['skippedBinary'], 3);
  });

  test('does not allow raising the one MiB ceiling', () {
    expect(
      () => LocalFileConnector(
        rootsProvider: () async => const [],
        maxFileBytes: maxLocalFileBytes + 1,
      ),
      throwsRangeError,
    );
  });

  test(
    'revalidates roots so revocation does not leak search results',
    () async {
      await File(
        '${root.path}${Platform.pathSeparator}secret.txt',
      ).writeAsString('revogar agora');
      var providerCalls = 0;
      final connector = LocalFileConnector(
        rootsProvider:
            () async =>
                providerCalls++ == 0
                    ? [LocalFileRoot(id: 'docs', path: root.path)]
                    : const [],
      );

      final result = await AgentConnectorRegistry(
        connector.tools,
      ).execute(searchLocalFilesToolName, {'query': 'revogar'}, _context());

      expect(_matches(result), isEmpty);
      expect(result.evidence, isEmpty);
    },
  );

  test('revalidates roots after a read', () async {
    await File(
      '${root.path}${Platform.pathSeparator}secret.txt',
    ).writeAsString('revogar agora');
    var providerCalls = 0;
    final connector = LocalFileConnector(
      rootsProvider:
          () async =>
              providerCalls++ == 0
                  ? [LocalFileRoot(id: 'docs', path: root.path)]
                  : const [],
    );

    await expectLater(
      AgentConnectorRegistry(connector.tools).execute(readLocalFileToolName, {
        'rootId': 'docs',
        'path': 'secret.txt',
      }, _context()),
      throwsA(isA<LocalFileAccessException>()),
    );
  });

  test('honors cancellation during periodic revalidation', () async {
    await File(
      '${root.path}${Platform.pathSeparator}secret.txt',
    ).writeAsString('cancelar agora');
    final cancelToken = CancelToken();
    var providerCalls = 0;
    final connector = LocalFileConnector(
      rootsProvider: () async {
        providerCalls++;
        if (providerCalls == 1) cancelToken.cancel();
        return [LocalFileRoot(id: 'docs', path: root.path)];
      },
    );

    await expectLater(
      AgentConnectorRegistry(connector.tools).execute(
        searchLocalFilesToolName,
        {'query': 'cancelar'},
        _context(cancelToken: cancelToken),
      ),
      throwsA(isA<ConnectorCancelledException>()),
    );
  });

  test('checks the tool, surface and conversation permission matrix', () async {
    String? checkedTool;
    ConnectorAccess? checkedAccess;
    ConnectorSurface? checkedSurface;
    int? checkedConversation;
    final registry = AgentConnectorRegistry(_connector(root).tools);
    final context = ConnectorRunContext(
      surface: ConnectorSurface.mcp,
      conversationId: 42,
      deadline: DateTime.now().add(const Duration(minutes: 1)),
      permissionChecker: (tool, access, surface, conversationId) async {
        checkedTool = tool;
        checkedAccess = access;
        checkedSurface = surface;
        checkedConversation = conversationId;
        return false;
      },
    );

    await expectLater(
      registry.execute(searchLocalFilesToolName, {
        'query': 'anything',
      }, context),
      throwsA(isA<ConnectorPermissionException>()),
    );
    expect(checkedTool, searchLocalFilesToolName);
    expect(checkedAccess, ConnectorAccess.read);
    expect(checkedSurface, ConnectorSurface.mcp);
    expect(checkedConversation, 42);
  });
}

LocalFileConnector _connector(Directory root) => LocalFileConnector(
  rootsProvider: () async => [LocalFileRoot(id: 'docs', path: root.path)],
);

ConnectorRunContext _context({CancelToken? cancelToken}) => ConnectorRunContext(
  surface: ConnectorSurface.desktop,
  deadline: DateTime.now().add(const Duration(minutes: 1)),
  cancelToken: cancelToken,
  permissionChecker: (_, _, _, _) async => true,
);

List<Map<String, Object?>> _matches(ConnectorToolResult result) =>
    ((result.data! as Map<String, Object?>)['matches']! as List<Object?>)
        .cast<Map<String, Object?>>();
