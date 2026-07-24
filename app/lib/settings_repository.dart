import 'package:kangoos_core/kangoos_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  static const _providerKey = 'llm_provider';
  static const _modelKey = 'llm_model';
  static const _apiKeyKey = 'llm_api_key';
  static const _baseUrlKey = 'llm_base_url';

  Future<LlmSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = LlmProviderKind.values.firstWhere(
      (kind) => kind.name == prefs.getString(_providerKey),
      orElse: () => LlmSettings.defaults.provider,
    );
    return LlmSettings(
      provider: provider,
      model: prefs.getString(_modelKey) ?? LlmSettings.defaults.model,
      apiKey: prefs.getString(_apiKeyKey) ?? '',
      baseUrl: prefs.getString(_baseUrlKey) ?? '',
    );
  }

  Future<void> save(LlmSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, settings.provider.name);
    await prefs.setString(_modelKey, settings.model);
    await prefs.setString(_apiKeyKey, settings.apiKey);
    await prefs.setString(_baseUrlKey, settings.baseUrl);
  }
}
