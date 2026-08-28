import 'dart:ffi';
import 'dart:io';

import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:sqlite3/open.dart';
import 'package:test/test.dart';

const _libraryEnvironmentKey = 'KANGOOS_SQLCIPHER_LIBRARY';

void main() {
  final libraryPath = Platform.environment[_libraryEnvironmentKey];

  test(
    'an encrypted database upgrade preserves existing snippets',
    () async {
      open.overrideFor(
        OperatingSystem.windows,
        () => DynamicLibrary.open(libraryPath!),
      );
      addTearDown(open.reset);

      final directory =
          Directory.systemTemp.createTempSync('kangoos_encrypted_upgrade');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/kangoos.db');
      const key = 'm0-upgrade-test-key';

      final initial = KangoosDatabase.native(file, encryptionKey: key);
      await initial.createSnippet(
        SnippetsCompanion.insert(title: 'Preserved', content: 'Encrypted data'),
      );
      await initial.customStatement('PRAGMA user_version = 17;');
      await initial.close();

      expect(KangoosDatabase.isPlaintextDatabase(file), isFalse);

      final upgraded = KangoosDatabase.native(file, encryptionKey: key);
      addTearDown(upgraded.close);

      final snippets = await upgraded.allSnippets();
      expect(snippets.single.title, 'Preserved');
      expect(snippets.single.content, 'Encrypted data');
    },
    skip: libraryPath == null
        ? 'Set $_libraryEnvironmentKey to the bundled SQLCipher library.'
        : false,
  );
}
