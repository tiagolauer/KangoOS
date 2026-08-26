import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_app/connectors/browser_profile_discovery.dart';
import 'package:kangoos_app/connectors/connector_credentials.dart';
import 'package:kangoos_app/connectors/connector_runtime.dart';
import 'package:kangoos_app/connectors/connector_settings_screen.dart';
import 'package:kangoos_app/secure_credential_store.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';

class _MemoryCredentialStore implements SecureCredentialStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _NoBrowserProfiles extends BrowserProfileDiscovery {
  @override
  Future<List<BrowserProfile>> discover() async => const [];
}

void main() {
  test(
    'disabled source disappears from the active tool list immediately',
    () async {
      final database = KangoosDatabase.memory();
      final directory = await Directory.systemTemp.createTemp('kangoos-m6-');
      addTearDown(database.close);
      addTearDown(() => directory.delete(recursive: true));
      final repository = SqliteConnectorRepository(database);
      final conversations = SqliteConversationRepository(database);
      final conversationId = await conversations.create();
      final source = await repository.upsertSource(
        ConnectorSourceInput(
          id: 'file:test',
          kind: ConnectorSourceKind.file,
          label: 'Teste',
          location: directory.path,
        ),
      );
      await repository.grantTool(
        surface: ConnectorSurface.desktop,
        conversationId: conversationId,
        toolName: searchLocalFilesToolName,
        access: ConnectorAccess.read,
      );
      final runtime = ConnectorRuntime(
        repository: repository,
        credentials: ConnectorCredentials(
          secureStore: _MemoryCredentialStore(),
        ),
      );
      final session = await runtime.open();
      addTearDown(session.close);
      final context = ConnectorRunContext(
        surface: ConnectorSurface.desktop,
        conversationId: conversationId,
        deadline: DateTime.now().add(const Duration(seconds: 5)),
        permissionChecker: session.permissionChecker,
      );

      expect(
        (await session.registry.definitionsFor(
          context,
        )).map((tool) => tool.name),
        [searchLocalFilesToolName],
      );

      await repository.upsertSource(
        ConnectorSourceInput(
          id: source.id,
          kind: source.kind,
          label: source.label,
          location: source.location,
          enabled: false,
        ),
      );

      expect(await session.registry.definitionsFor(context), isEmpty);
    },
  );

  test(
    'a second source cannot keep a disabled bound connector alive',
    () async {
      final database = KangoosDatabase.memory();
      addTearDown(database.close);
      final repository = SqliteConnectorRepository(database);
      final conversationId =
          await SqliteConversationRepository(database).create();
      final first = await repository.upsertSource(
        const ConnectorSourceInput(
          id: 'web:first',
          kind: ConnectorSourceKind.web,
          label: 'A',
          location: 'https://search-a.example/search',
        ),
      );
      await repository.upsertSource(
        const ConnectorSourceInput(
          id: 'web:second',
          kind: ConnectorSourceKind.web,
          label: 'B',
          location: 'https://search-b.example/search',
        ),
      );
      await repository.grantTool(
        surface: ConnectorSurface.desktop,
        conversationId: conversationId,
        toolName: 'search_web',
        access: ConnectorAccess.external,
      );
      final runtime = ConnectorRuntime(
        repository: repository,
        credentials: ConnectorCredentials(
          secureStore: _MemoryCredentialStore(),
        ),
      );
      final session = await runtime.open();
      addTearDown(session.close);
      final context = ConnectorRunContext(
        surface: ConnectorSurface.desktop,
        conversationId: conversationId,
        deadline: DateTime.now().add(const Duration(seconds: 5)),
        permissionChecker: session.permissionChecker,
      );
      expect(
        (await session.registry.definitionsFor(
          context,
        )).map((tool) => tool.name),
        ['search_web'],
      );

      await repository.upsertSource(
        ConnectorSourceInput(
          id: first.id,
          kind: first.kind,
          label: first.label,
          location: first.location,
          enabled: false,
        ),
      );

      expect(await session.registry.definitionsFor(context), isEmpty);

      await repository.upsertSource(
        const ConnectorSourceInput(
          id: 'web:first',
          kind: ConnectorSourceKind.web,
          label: 'A alterado',
          location: 'https://replacement.example/search',
        ),
      );

      expect(await session.registry.definitionsFor(context), isEmpty);
    },
  );

  test('calendar credentials remain only in the secure store', () async {
    final secureStore = _MemoryCredentialStore();
    final credentials = ConnectorCredentials(secureStore: secureStore);

    await credentials.saveCalendar(
      const CalendarCredentials(username: 'user', password: 'secret'),
    );

    expect((await credentials.loadCalendar()).password, 'secret');
    expect(secureStore.values.values, containsAll(['user', 'secret']));
  });

  test(
    'missing calendar credentials isolate CalDAV without blocking other tools',
    () async {
      final database = KangoosDatabase.memory();
      addTearDown(database.close);
      final repository = SqliteConnectorRepository(database);
      final conversationId =
          await SqliteConversationRepository(database).create();
      await repository.upsertSource(
        const ConnectorSourceInput(
          id: 'calendar:primary',
          kind: ConnectorSourceKind.calendar,
          label: 'Calendário CalDAV',
          location: 'https://calendar.example/dav/',
        ),
      );
      await repository.upsertSource(
        const ConnectorSourceInput(
          id: 'web:searxng',
          kind: ConnectorSourceKind.web,
          label: 'Pesquisa web',
          location: 'https://search.example/search',
        ),
      );
      await repository.grantTool(
        surface: ConnectorSurface.desktop,
        conversationId: conversationId,
        toolName: 'search_web',
        access: ConnectorAccess.external,
      );
      final runtime = ConnectorRuntime(
        repository: repository,
        credentials: ConnectorCredentials(
          secureStore: _MemoryCredentialStore(),
        ),
      );
      final session = await runtime.open();
      addTearDown(session.close);
      final context = ConnectorRunContext(
        surface: ConnectorSurface.desktop,
        conversationId: conversationId,
        deadline: DateTime.now().add(const Duration(seconds: 5)),
        permissionChecker: session.permissionChecker,
      );

      expect(
        (await session.registry.definitionsFor(
          context,
        )).map((tool) => tool.name),
        ['search_web'],
      );
    },
  );

  testWidgets('missing calendar credentials are visible as a paused source', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final repository = SqliteConnectorRepository(database);
    await repository.upsertSource(
      const ConnectorSourceInput(
        id: 'calendar:primary',
        kind: ConnectorSourceKind.calendar,
        label: 'Calendário CalDAV',
        location: 'https://calendar.example/dav/',
      ),
    );
    final conversationId =
        await SqliteConversationRepository(database).create();

    await tester.pumpWidget(
      MaterialApp(
        home: ConnectorSettingsScreen(
          repository: repository,
          credentials: ConnectorCredentials(
            secureStore: _MemoryCredentialStore(),
          ),
          persona: PersonaService(
            repository: SqlitePersonaRepository(database),
            summaries: SqliteSummaryRepository(database),
          ),
          conversationId: conversationId,
          browserDiscovery: _NoBrowserProfiles(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Conector pausado'), findsOneWidget);
  });

  testWidgets('permission matrix persists the explicit conversation grant', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final repository = SqliteConnectorRepository(database);
    final conversationId =
        await SqliteConversationRepository(database).create();
    final credentials = ConnectorCredentials(
      secureStore: _MemoryCredentialStore(),
    );
    final persona = PersonaService(
      repository: SqlitePersonaRepository(database),
      summaries: SqliteSummaryRepository(database),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ConnectorSettingsScreen(
          repository: repository,
          credentials: credentials,
          persona: persona,
          conversationId: conversationId,
          browserDiscovery: _NoBrowserProfiles(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conectores e permissões'), findsOneWidget);
    await tester.ensureVisible(find.text('Buscar arquivos locais'));
    await tester.tap(find.text('Buscar arquivos locais'));
    await tester.pumpAndSettle();

    expect(
      await repository.isToolAllowed(
        surface: ConnectorSurface.desktop,
        conversationId: conversationId,
        toolName: searchLocalFilesToolName,
        access: ConnectorAccess.read,
      ),
      isTrue,
    );
  });
}
