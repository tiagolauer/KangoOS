import 'package:shared_preferences/shared_preferences.dart';

const defaultRetentionDays = 30;

class CaptureSettings {
  const CaptureSettings({
    this.paused = false,
    this.excludedApps = const [],
    this.retentionDays = defaultRetentionDays,
    this.captureBrowserUrls = false,
  });

  final bool paused;
  final List<String> excludedApps;

  /// Activities older than this are purged. 0 means keep forever.
  final int retentionDays;

  /// Opt-in: also records the active tab's URL for recognized browsers.
  final bool captureBrowserUrls;

  CaptureSettings copyWith({
    bool? paused,
    List<String>? excludedApps,
    int? retentionDays,
    bool? captureBrowserUrls,
  }) {
    return CaptureSettings(
      paused: paused ?? this.paused,
      excludedApps: excludedApps ?? this.excludedApps,
      retentionDays: retentionDays ?? this.retentionDays,
      captureBrowserUrls: captureBrowserUrls ?? this.captureBrowserUrls,
    );
  }
}

class CaptureSettingsRepository {
  static const _pausedKey = 'capture_paused';
  static const _excludedAppsKey = 'capture_excluded_apps';
  static const _retentionDaysKey = 'capture_retention_days';
  static const _captureBrowserUrlsKey = 'capture_browser_urls';

  Future<CaptureSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return CaptureSettings(
      paused: prefs.getBool(_pausedKey) ?? false,
      excludedApps: prefs.getStringList(_excludedAppsKey) ?? const [],
      retentionDays: prefs.getInt(_retentionDaysKey) ?? defaultRetentionDays,
      captureBrowserUrls: prefs.getBool(_captureBrowserUrlsKey) ?? false,
    );
  }

  Future<void> save(CaptureSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pausedKey, settings.paused);
    await prefs.setStringList(_excludedAppsKey, settings.excludedApps);
    await prefs.setInt(_retentionDaysKey, settings.retentionDays);
    await prefs.setBool(_captureBrowserUrlsKey, settings.captureBrowserUrls);
  }
}
