import 'package:flutter_test/flutter_test.dart';

import 'package:kangoos_app/database_encryption.dart';
import 'package:kangoos_app/secure_credential_store.dart';

class _FakeSecureCredentialStore implements SecureCredentialStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

void main() {
  test('getOrCreateKey generates and persists a key on first call', () async {
    final store = _FakeSecureCredentialStore();
    final provider = DatabaseEncryptionKeyProvider(store: store);

    final key = await provider.getOrCreateKey();

    expect(key, hasLength(64));
    expect(await store.read('db_encryption_key'), key);
  });

  test('getOrCreateKey returns the same key on subsequent calls', () async {
    final store = _FakeSecureCredentialStore();
    final provider = DatabaseEncryptionKeyProvider(store: store);

    final first = await provider.getOrCreateKey();
    final second = await provider.getOrCreateKey();

    expect(second, first);
  });

  test('two providers generate different keys', () async {
    final keyA =
        await DatabaseEncryptionKeyProvider(store: _FakeSecureCredentialStore())
            .getOrCreateKey();
    final keyB =
        await DatabaseEncryptionKeyProvider(store: _FakeSecureCredentialStore())
            .getOrCreateKey();

    expect(keyA, isNot(keyB));
  });
}
