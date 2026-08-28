import 'dart:io';

import 'package:kangoos_core/src/connectors/connector_repository.dart';
import 'package:kangoos_core/src/database/database.dart';
import 'package:kangoos_core/src/database/tables/agent_context_tables.dart';
import 'package:kangoos_core/src/infrastructure/sqlite/sqlite_connector_repository.dart';
import 'package:test/test.dart';

void main() {
  test(
    'schema 21 upgrades to M6 storage without losing existing data',
    () async {
      final directory = Directory.systemTemp.createTempSync(
        'kangoos_m6_upgrade',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/kangoos.db');

      final previous = KangoosDatabase.native(file);
      await previous.createSnippet(
        SnippetsCompanion.insert(title: 'Preserved', content: 'Existing data'),
      );
      await previous.customStatement('DROP TABLE connector_tool_permissions;');
      await previous.customStatement('DROP TABLE connector_sources;');
      await previous.customStatement('DROP TABLE local_personas;');
      await previous.customStatement('PRAGMA user_version = 21;');
      await previous.close();

      final upgraded = KangoosDatabase.native(file);
      addTearDown(upgraded.close);
      expect((await upgraded.allSnippets()).single.title, 'Preserved');

      final source = await SqliteConnectorRepository(upgraded).upsertSource(
        const ConnectorSourceInput(
          id: 'web-docs',
          kind: ConnectorSourceKind.web,
          label: 'Docs',
          location: 'https://example.test/docs',
        ),
      );
      expect(source.id, 'web-docs');
      expect(KangoosDatabase.currentSchemaVersion, 22);
    },
  );
}
