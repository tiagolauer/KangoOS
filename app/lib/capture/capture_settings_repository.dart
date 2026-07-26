import 'package:shared_preferences/shared_preferences.dart';

const defaultRetentionDays = 30;

class CaptureSettings {
  const CaptureSettings({
    this.paused = false,
    this.excludedApps = const [],
    this.retentionDays = defaultRetentionDays,
    this.captureVisibleText = false,
    this.captureBrowserUrls = false,
    this.captureClipboard = false,
  });

  final bool paused;
  final List<String> excludedApps;
  final int retentionDays;
  final bool captureVisibleText;

  /// Opt-in: also records the active tab's URL for recognized browsers.
  final bool captureBrowserUrls;

  final bool captureClipboard;

  CaptureSettings copyWith({
    bool? paused,
    List<String>? excludedApps,
    int? retentionDays,
    bool? captureVisibleText,
    bool? captureBrowserUrls,
    bool? captureClipboard,
  }) {
    return CaptureSettings(
      paused: paused ?? this.paused,
      excludedApps: excludedApps ?? this.excludedApps,
      retentionDays: retentionDays ?? this.retentionDays,
      captureVisibleText: captureVisibleText ?? this.captureVisibleText,
      captureBrowserUrls: captureBrowserUrls ?? this.captureBrowserUrls,
      captureClipboard: captureClipboard ?? this.captureClipboard,
    );
  }
}

class CaptureSettingsRepository {
  static const _pausedKey = 'capture_paused';
  static const _excludedAppsKey = 'capture_excluded_apps';
  static const _retentionDaysKey = 'capture_retention_days';
  static const _captureVisibleTextKey = 'capture_visible_text';
  static const _captureBrowserUrlsKey = 'capture_browser_urls';
  static const _captureClipboardKey = 'capture_clipboard';
  static const _consentShownKey = 'capture_consent_shown';

  Future<CaptureSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return CaptureSettings(
      paused: prefs.getBool(_pausedKey) ?? false,
      excludedApps: prefs.getStringList(_excludedAppsKey) ?? const [],
      retentionDays: prefs.getInt(_retentionDaysKey) ?? defaultRetentionDays,
      captureVisibleText: prefs.getBool(_captureVisibleTextKey) ?? false,
      captureBrowserUrls: prefs.getBool(_captureBrowserUrlsKey) ?? false,
      captureClipboard: prefs.getBool(_captureClipboardKey) ?? false,
    );
  }

  Future<void> save(CaptureSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pausedKey, settings.paused);
    await prefs.setStringList(_excludedAppsKey, settings.excludedApps);
    await prefs.setInt(_retentionDaysKey, settings.retentionDays);
    await prefs.setBool(_captureVisibleTextKey, settings.captureVisibleText);
    await prefs.setBool(_captureBrowserUrlsKey, settings.captureBrowserUrls);
    await prefs.setBool(_captureClipboardKey, settings.captureClipboard);
  }

  Future<bool> hasShownConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentShownKey) ?? false;
  }

  Future<void> markConsentShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentShownKey, true);
  }
}
