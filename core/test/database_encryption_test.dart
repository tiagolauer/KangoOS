import 'dart:io';

import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('kangoos_db_test'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  test('native() without an encryption key opens a plain database', () async {
    final file = File('${tempDir.path}/plain.db');
    final database = KangoosDatabase.native(file);
    addTearDown(database.close);

    await database
        .createSnippet(SnippetsCompanion.insert(title: 'a', content: 'b'));
    expect(await database.allSnippets(), hasLength(1));
  });

  test(
      'native() with an encryption key refuses to open when the sqlite3 '
      'library lacks SQLCipher support (fails loudly, never falls back to '
      'plaintext)', () async {
    final file = File('${tempDir.path}/encrypted.db');
    final database = KangoosDatabase.native(file, encryptionKey: 'a-test-key');
    addTearDown(database.close);

    await expectLater(database.allSnippets(), throwsA(isA<StateError>()));
  });

  group('isPlaintextDatabase', () {
    test('detects a real unencrypted database', () async {
      final file = File('${tempDir.path}/plain.db');
      final database = KangoosDatabase.native(file);
      await database
          .createSnippet(SnippetsCompanion.insert(title: 'a', content: 'b'));
      await database.close();

      expect(KangoosDatabase.isPlaintextDatabase(file), isTrue);
    });

    test('is false for a missing file', () {
      expect(
          KangoosDatabase.isPlaintextDatabase(File('${tempDir.path}/nope.db')),
          isFalse);
    });

    test('is false for a file that does not start with the SQLite header', () {
      final file = File('${tempDir.path}/encrypted-looking.db')
        ..writeAsBytesSync(List<int>.generate(64, (i) => (i * 7) % 251));
      expect(KangoosDatabase.isPlaintextDatabase(file), isFalse);
    });

    test('is false for a file shorter than the header', () {
      final file = File('${tempDir.path}/tiny.db')..writeAsStringSync('SQL');
      expect(KangoosDatabase.isPlaintextDatabase(file), isFalse);
    });
  });

  test('removePlaintextBackups removes legacy plaintext copies only', () {
    final databaseFile = File('${tempDir.path}/kangoos.db');
    final first = File('${databaseFile.path}.plaintext-backup')
      ..writeAsStringSync('plain');
    final second = File('${databaseFile.path}.plaintext-backup-2')
      ..writeAsStringSync('plain');
    final unrelated = File('${databaseFile.path}.backup')
      ..writeAsStringSync('keep');

    KangoosDatabase.removePlaintextBackups(databaseFile);

    expect(first.existsSync(), isFalse);
    expect(second.existsSync(), isFalse);
    expect(unrelated.existsSync(), isTrue);
  });

  group('databaseEncryptionKeyFromEnvironment', () {
    test('prefers a key file and trims its contents', () {
      final key = databaseEncryptionKeyFromEnvironment(
        {
          databaseKeyFileEnvironmentKey: 'secret.txt',
          databaseKeyEnvironmentKey: 'fallback',
        },
        readFile: (_) => ' file-key\n',
      );

      expect(key, 'file-key');
    });

    test('returns null when no key was configured', () {
      expect(databaseEncryptionKeyFromEnvironment(const {}), isNull);
    });

    test('rejects an empty configured key file', () {
      expect(
        () => databaseEncryptionKeyFromEnvironment(
          {databaseKeyFileEnvironmentKey: 'secret.txt'},
          readFile: (_) => '  ',
        ),
        throwsStateError,
      );
    });
  });
}
