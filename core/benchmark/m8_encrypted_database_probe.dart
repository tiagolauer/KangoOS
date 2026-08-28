import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

const _databasePathKey = 'KANGOOS_M8_DATABASE_PATH';
const _databaseKeyKey = 'KANGOOS_M8_DATABASE_KEY';
const _libraryPathKey = 'KANGOOS_SQLCIPHER_LIBRARY';
const _tables = [
  'snippets',
  'activities',
  'activity_summaries',
  'conversations',
  'conversation_messages',
  'deleted_snippets',
  'memory_episodes',
];

void main() {
  if (!Platform.isWindows) {
    throw UnsupportedError('The installed database probe requires Windows.');
  }
  final environment = Platform.environment;
  final databasePath = _required(environment, _databasePathKey);
  final libraryPath = _required(environment, _libraryPathKey);
  final key = _required(environment, _databaseKeyKey);

  open.overrideFor(
    OperatingSystem.windows,
    () => DynamicLibrary.open(libraryPath),
  );
  final database = sqlite3.open(databasePath, mode: OpenMode.readOnly);
  try {
    final escapedKey = key.replaceAll("'", "''");
    database.execute("PRAGMA key = '$escapedKey';");
    final cipherVersion = database.select('PRAGMA cipher_version;');
    if (cipherVersion.isEmpty) throw StateError('SQLCipher is unavailable.');
    final integrity =
        database.select('PRAGMA integrity_check;').single.values.single;
    if (integrity != 'ok') throw StateError('Database integrity check failed.');

    final existingTables =
        database
            .select("SELECT name FROM sqlite_master WHERE type = 'table';")
            .map((row) => row['name'] as String)
            .toSet();
    final counts = <String, int>{};
    for (final table in _tables.where(existingTables.contains)) {
      counts[table] =
          database
                  .select('SELECT count(*) AS total FROM $table;')
                  .single['total']
              as int;
    }
    stdout.writeln(
      jsonEncode({
        'userVersion': database.userVersion,
        'integrity': integrity,
        'counts': counts,
      }),
    );
  } finally {
    database.dispose();
  }
}

String _required(Map<String, String> environment, String key) {
  final value = environment[key]?.trim() ?? '';
  if (value.isEmpty) throw StateError('$key is required.');
  return value;
}
