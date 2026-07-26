import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() => tempDir = Directory.systemTemp.createTempSync('kangoos_db_test'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  test('native() without an encryption key opens a plain database', () async {
    final file = File('${tempDir.path}/plain.db');
    final database = KangoosDatabase.native(file);
    addTearDown(database.close);

    await database.createSnippet(
        SnippetsCompanion.insert(title: 'a', content: 'b'));
    expect(await database.allSnippets(), hasLength(1));
  });

  test('native() with an encryption key refuses to open when the sqlite3 '
      'library lacks SQLCipher support (fails loudly, never falls back to '
      'plaintext)', () async {
    final file = File('${tempDir.path}/encrypted.db');

    await expectLater(() async {
      final database =
          KangoosDatabase.native(file, encryptionKey: 'a-test-key');
      await database.allSnippets();
    }, throwsA(isA<StateError>()));
  });

  group('isPlaintextDatabase', () {
    test('detects a real unencrypted database', () async {
      final file = File('${tempDir.path}/plain.db');
      final database = KangoosDatabase.native(file);
      await database.createSnippet(
          SnippetsCompanion.insert(title: 'a', content: 'b'));
      await database.close();

      expect(KangoosDatabase.isPlaintextDatabase(file), isTrue);
    });

    test('is false for a missing file', () {
      expect(
          KangoosDatabase.isPlaintextDatabase(
              File('${tempDir.path}/nope.db')),
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
}
