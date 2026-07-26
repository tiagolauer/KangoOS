import 'package:shared_preferences/shared_preferences.dart';

import '../secure_credential_store.dart';

class SyncSettings {
  const SyncSettings({this.serverUrl = '', this.apiToken = ''});

  final String serverUrl;
  final String apiToken;

  SyncSettings copyWith({String? serverUrl, String? apiToken}) => SyncSettings(
        serverUrl: serverUrl ?? this.serverUrl,
        apiToken: apiToken ?? this.apiToken,
      );
}

class SyncSettingsRepository {
  SyncSettingsRepository({SecureCredentialStore? secureStore})
      : _secureStore = secureStore ?? const FlutterSecureCredentialStore();

  final SecureCredentialStore _secureStore;

  static const _serverUrlKey = 'sync_server_url';
  static const _apiTokenKey = 'sync_api_token';

  Future<SyncSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SyncSettings(
      serverUrl: prefs.getString(_serverUrlKey) ?? '',
      apiToken: await _secureStore.read(_apiTokenKey) ?? '',
    );
  }

  Future<void> save(SyncSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, settings.serverUrl);
    if (settings.apiToken.isEmpty) {
      await _secureStore.delete(_apiTokenKey);
    } else {
      await _secureStore.write(_apiTokenKey, settings.apiToken);
    }
  }
}
