import 'package:kangoos_core/src/connectors/agent_connector.dart';
import 'package:kangoos_core/src/connectors/connector_repository.dart';
import 'package:kangoos_core/src/database/database.dart';
import 'package:kangoos_core/src/database/tables/agent_context_tables.dart';
import 'package:kangoos_core/src/infrastructure/sqlite/sqlite_connector_repository.dart';
import 'package:test/test.dart';

void main() {
  late KangoosDatabase database;
  late SqliteConnectorRepository repository;

  setUp(() {
    database = KangoosDatabase.memory();
    repository = SqliteConnectorRepository(database);
  });

  tearDown(() => database.close());

  test('persists only typed non-secret connector source settings', () async {
    final created = await repository.upsertSource(
      const ConnectorSourceInput(
        id: 'workspace',
        kind: ConnectorSourceKind.file,
        label: 'Workspace',
        location: r'F:\Fontes\opensource\KangoOS',
      ),
    );
    expect(created.id, 'workspace');
    expect(created.kind, ConnectorSourceKind.file);
    expect(created.enabled, isTrue);

    final updated = await repository.upsertSource(
      const ConnectorSourceInput(
        id: 'workspace',
        kind: ConnectorSourceKind.file,
        label: 'Workspace disabled',
        location: r'F:\Fontes\opensource\KangoOS',
        enabled: false,
      ),
    );
    expect(updated.createdAt, created.createdAt);
    expect(await repository.sources(enabled: true), isEmpty);
    expect(
      (await repository.sources(enabled: false)).single.label,
      'Workspace disabled',
    );

    expect(
      repository.upsertSource(
        const ConnectorSourceInput(
          id: 'unsafe',
          kind: ConnectorSourceKind.web,
          label: 'Unsafe',
          location: 'https://example.test/?token=super-secret-value',
        ),
      ),
      throwsArgumentError,
    );
    expect(
      repository.upsertSource(
        const ConnectorSourceInput(
          id: 'basic-auth',
          kind: ConnectorSourceKind.web,
          label: 'Unsafe',
          location: 'https://user:password@example.test/docs',
        ),
      ),
      throwsArgumentError,
    );
    expect(await repository.deleteSource('workspace'), 1);
  });

  test(
    'tool grants are exact, deny by default and die with conversation',
    () async {
      final conversationId = await database.createConversation();
      expect(
        await repository.isToolAllowed(
          surface: ConnectorSurface.desktop,
          conversationId: conversationId,
          toolName: 'read_file',
          access: ConnectorAccess.read,
        ),
        isFalse,
      );
      expect(
        await repository.isToolAllowed(
          surface: ConnectorSurface.desktop,
          conversationId: null,
          toolName: 'read_file',
          access: ConnectorAccess.read,
        ),
        isFalse,
      );
      expect(
        repository.grantTool(
          surface: ConnectorSurface.desktop,
          conversationId: conversationId + 999,
          toolName: 'read_file',
          access: ConnectorAccess.read,
        ),
        throwsStateError,
      );

      await repository.grantTool(
        surface: ConnectorSurface.desktop,
        conversationId: conversationId,
        toolName: 'read_file',
        access: ConnectorAccess.read,
      );
      await repository.grantTool(
        surface: ConnectorSurface.desktop,
        conversationId: conversationId,
        toolName: 'read_file',
        access: ConnectorAccess.read,
      );

      expect(
        await repository.isToolAllowed(
          surface: ConnectorSurface.desktop,
          conversationId: conversationId,
          toolName: 'read_file',
          access: ConnectorAccess.read,
        ),
        isTrue,
      );
      expect(
        await repository.isToolAllowed(
          surface: ConnectorSurface.server,
          conversationId: conversationId,
          toolName: 'read_file',
          access: ConnectorAccess.read,
        ),
        isFalse,
      );
      expect(
        await repository.isToolAllowed(
          surface: ConnectorSurface.desktop,
          conversationId: conversationId,
          toolName: 'read_file',
          access: ConnectorAccess.write,
        ),
        isFalse,
      );
      expect(
        await repository.permissionsForConversation(conversationId),
        hasLength(1),
      );

      expect(
        await repository.revokeTool(
          surface: ConnectorSurface.desktop,
          conversationId: conversationId,
          toolName: 'read_file',
          access: ConnectorAccess.read,
        ),
        1,
      );
      expect(
        await repository.isToolAllowed(
          surface: ConnectorSurface.desktop,
          conversationId: conversationId,
          toolName: 'read_file',
          access: ConnectorAccess.read,
        ),
        isFalse,
      );
      await repository.grantTool(
        surface: ConnectorSurface.desktop,
        conversationId: conversationId,
        toolName: 'read_file',
        access: ConnectorAccess.read,
      );

      await database.deleteConversation(conversationId);
      expect(
        await repository.permissionsForConversation(conversationId),
        isEmpty,
      );
      expect(
        await repository.isToolAllowed(
          surface: ConnectorSurface.desktop,
          conversationId: conversationId,
          toolName: 'read_file',
          access: ConnectorAccess.read,
        ),
        isFalse,
      );
    },
  );
}
