import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:sqlite3/open.dart';
import 'package:test/test.dart';

const _libraryEnvironmentKey = 'KANGOOS_SQLCIPHER_LIBRARY';

void main() {
  final libraryPath = Platform.environment[_libraryEnvironmentKey];

  test(
    'encrypted backup restores exact records and search indexes',
    () async {
      open.overrideFor(
        OperatingSystem.windows,
        () => DynamicLibrary.open(libraryPath!),
      );
      addTearDown(open.reset);
      final directory = Directory.systemTemp.createTempSync(
        'kangoos_encrypted_backup',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final databaseFile = File('${directory.path}/kangoos.db');
      final backupFile = File('${directory.path}/ltm-backup.db');
      const key = 'm2-backup-test-key';
      final capturedAt = DateTime.utc(2026, 8, 25, 14, 37, 12);

      final source = KangoosDatabase.native(databaseFile, encryptionKey: key);
      final activityId = await source.logActivity(
        ActivitiesCompanion.insert(
          appName: 'Editor',
          windowTitle: 'Architecture',
          capturedText: const Value('restore-marker-48'),
          capturedAt: Value(capturedAt),
        ),
      );
      final episodes = SqliteEpisodeRepository(source);
      final episodeId = await episodes.create(
        NewMemoryEpisode(
          sourceKey: 'restore-source',
          startedAt: capturedAt,
          endedAt: capturedAt.add(const Duration(minutes: 3)),
          title: 'Restore marker',
          summary: 'restore-marker-48',
          applications: const ['Editor'],
          urls: const [],
          topics: const ['backup'],
          entities: const [],
          sourceActivityIds: [activityId],
        ),
      );
      await episodes.setEmbedding(episodeId, const [1, 0], 'backup-test');
      await source.createBackup(backupFile);
      expect(KangoosDatabase.isPlaintextDatabase(backupFile), isFalse);

      await source.deleteMemory(const MemoryDeletionFilter());
      expect(await source.searchActivities('restore-marker-48'), isEmpty);
      await source.stageRestore(backupFile);
      await source.close();

      KangoosDatabase.applyPendingRestore(databaseFile, key);
      final restored = KangoosDatabase.native(databaseFile, encryptionKey: key);
      addTearDown(restored.close);
      final restoredActivity =
          (await restored.searchActivities('restore-marker-48')).single;
      final restoredEpisode =
          (await SqliteEpisodeRepository(
            restored,
          ).searchKeyword('restore-marker-48')).single;
      expect(restoredActivity.id, activityId);
      expect(restoredActivity.capturedAt.isAtSameMomentAs(capturedAt), isTrue);
      expect(restoredEpisode.id, episodeId);
      expect(restoredEpisode.startedAt.isAtSameMomentAs(capturedAt), isTrue);
      expect(restoredEpisode.embedding, const [1, 0]);
    },
    skip:
        libraryPath == null
            ? 'Set $_libraryEnvironmentKey to the bundled SQLCipher library.'
            : false,
  );

  test(
    'creates an encrypted snapshot before a pending schema migration',
    () async {
      open.overrideFor(
        OperatingSystem.windows,
        () => DynamicLibrary.open(libraryPath!),
      );
      addTearDown(open.reset);
      final directory = Directory.systemTemp.createTempSync(
        'kangoos_pre_migration_backup',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final databaseFile = File('${directory.path}/kangoos.db');
      const key = 'm2-pre-migration-test-key';

      final database = KangoosDatabase.native(databaseFile, encryptionKey: key);
      await database.createSnippet(
        SnippetsCompanion.insert(
          title: 'Preserve before migration',
          content: 'pre-migration-marker-37',
        ),
      );
      await database.customStatement('PRAGMA user_version = 0;');
      await database.close();

      final backup = await KangoosDatabase.backupBeforeMigration(
        databaseFile,
        key,
      );
      expect(backup, isNotNull);
      expect(backup!.existsSync(), isTrue);
      expect(KangoosDatabase.isPlaintextDatabase(backup), isFalse);

      final snapshot = KangoosDatabase.native(backup, encryptionKey: key);
      addTearDown(snapshot.close);
      expect(
        (await snapshot.allSnippets()).single.content,
        'pre-migration-marker-37',
      );
    },
    skip:
        libraryPath == null
            ? 'Set $_libraryEnvironmentKey to the bundled SQLCipher library.'
            : false,
  );
}
