import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin seam over the OS keychain (Credential Manager on Windows, Keychain
/// on macOS, Secret Service/libsecret on Linux), so callers don't depend on
/// `flutter_secure_storage` directly and tests can inject an in-memory fake
/// instead of hitting a real platform channel.
abstract class SecureCredentialStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureCredentialStore implements SecureCredentialStore {
  const FlutterSecureCredentialStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
