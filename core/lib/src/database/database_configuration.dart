import 'dart:io';

const databasePathEnvironmentKey = 'KANGOOS_DB_PATH';
const databaseKeyEnvironmentKey = 'KANGOOS_DB_KEY';
const databaseKeyFileEnvironmentKey = 'KANGOOS_DB_KEY_FILE';

String? databaseEncryptionKeyFromEnvironment(
  Map<String, String> environment, {
  String Function(String path)? readFile,
}) {
  final keyFile = environment[databaseKeyFileEnvironmentKey]?.trim() ?? '';
  if (keyFile.isNotEmpty) {
    final value =
        readFile == null ? File(keyFile).readAsStringSync() : readFile(keyFile);
    final key = value.trim();
    if (key.isEmpty) {
      throw StateError(
          '$databaseKeyFileEnvironmentKey points to an empty file.');
    }
    return key;
  }
  final key = environment[databaseKeyEnvironmentKey]?.trim() ?? '';
  return key.isEmpty ? null : key;
}
