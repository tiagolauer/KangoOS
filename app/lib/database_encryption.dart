import 'dart:math';

import 'secure_credential_store.dart';

const _encryptionKeyStorageKey = 'db_encryption_key';

class DatabaseEncryptionKeyProvider {
  DatabaseEncryptionKeyProvider({SecureCredentialStore? store})
      : store = store ?? const FlutterSecureCredentialStore();

  final SecureCredentialStore store;

  Future<String> getOrCreateKey() async {
    final existing = await store.read(_encryptionKeyStorageKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final key = _generateKey();
    await store.write(_encryptionKeyStorageKey, key);
    return key;
  }

  static String _generateKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
