import 'package:shared_preferences/shared_preferences.dart';

const defaultRetentionDays = 30;

class CaptureSettings {
  const CaptureSettings({
    this.paused = false,
    this.resumeAt,
    this.excludedApps = const [],
    this.retentionDays = defaultRetentionDays,
    this.captureVisibleText = false,
    this.captureScreenText = false,
    this.captureAudio = false,
    this.captureBrowserUrls = false,
    this.captureClipboard = false,
    this.allowRemoteSummaries = false,
    this.redactPii = false,
  });

  final bool paused;
  final DateTime? resumeAt;
  final List<String> excludedApps;
  final int retentionDays;
  final bool captureVisibleText;
  final bool captureScreenText;
  final bool captureAudio;

  /// Opt-in: also records the active tab's URL for recognized browsers.
  final bool captureBrowserUrls;

  final bool captureClipboard;
  final bool allowRemoteSummaries;
  final bool redactPii;

  CaptureSettings copyWith({
    bool? paused,
    DateTime? resumeAt,
    bool clearResumeAt = false,
    List<String>? excludedApps,
    int? retentionDays,
    bool? captureVisibleText,
    bool? captureScreenText,
    bool? captureAudio,
    bool? captureBrowserUrls,
    bool? captureClipboard,
    bool? allowRemoteSummaries,
    bool? redactPii,
  }) {
    return CaptureSettings(
      paused: paused ?? this.paused,
      resumeAt: clearResumeAt ? null : resumeAt ?? this.resumeAt,
      excludedApps: excludedApps ?? this.excludedApps,
      retentionDays: retentionDays ?? this.retentionDays,
      captureVisibleText: captureVisibleText ?? this.captureVisibleText,
      captureScreenText: captureScreenText ?? this.captureScreenText,
      captureAudio: captureAudio ?? this.captureAudio,
      captureBrowserUrls: captureBrowserUrls ?? this.captureBrowserUrls,
      captureClipboard: captureClipboard ?? this.captureClipboard,
      allowRemoteSummaries: allowRemoteSummaries ?? this.allowRemoteSummaries,
      redactPii: redactPii ?? this.redactPii,
    );
  }
}

class CaptureSettingsRepository {
  static const _pausedKey = 'capture_paused';
  static const _resumeAtKey = 'capture_resume_at';
  static const _excludedAppsKey = 'capture_excluded_apps';
  static const _retentionDaysKey = 'capture_retention_days';
  static const _captureVisibleTextKey = 'capture_visible_text';
  static const _captureScreenTextKey = 'capture_screen_text';
  static const _captureAudioKey = 'capture_audio';
  static const _captureBrowserUrlsKey = 'capture_browser_urls';
  static const _captureClipboardKey = 'capture_clipboard';
  static const _allowRemoteSummariesKey = 'allow_remote_activity_summaries';
  static const _redactPiiKey = 'redact_captured_pii';
  static const _consentShownKey = 'capture_consent_shown';

  Future<CaptureSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final resumeAtValue = prefs.getString(_resumeAtKey);
    final resumeAt = resumeAtValue == null
        ? null
        : DateTime.tryParse(resumeAtValue)?.toLocal();
    var settings = CaptureSettings(
      paused: prefs.getBool(_pausedKey) ?? false,
      resumeAt: resumeAt,
      excludedApps: prefs.getStringList(_excludedAppsKey) ?? const [],
      retentionDays: prefs.getInt(_retentionDaysKey) ?? defaultRetentionDays,
      captureVisibleText: prefs.getBool(_captureVisibleTextKey) ?? false,
      captureScreenText: prefs.getBool(_captureScreenTextKey) ?? false,
      captureAudio: prefs.getBool(_captureAudioKey) ?? false,
      captureBrowserUrls: prefs.getBool(_captureBrowserUrlsKey) ?? false,
      captureClipboard: prefs.getBool(_captureClipboardKey) ?? false,
      allowRemoteSummaries: prefs.getBool(_allowRemoteSummariesKey) ?? false,
      redactPii: prefs.getBool(_redactPiiKey) ?? false,
    );
    if (settings.paused &&
        resumeAt != null &&
        !DateTime.now().isBefore(resumeAt)) {
      settings = settings.copyWith(paused: false, clearResumeAt: true);
      await _save(prefs, settings);
    }
    return settings;
  }

  Future<void> save(CaptureSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await _save(prefs, settings);
  }

  Future<void> _save(SharedPreferences prefs, CaptureSettings settings) async {
    await prefs.setBool(_pausedKey, settings.paused);
    final resumeAt = settings.paused ? settings.resumeAt : null;
    if (resumeAt != null) {
      await prefs.setString(_resumeAtKey, resumeAt.toUtc().toIso8601String());
    } else {
      await prefs.remove(_resumeAtKey);
    }
    await prefs.setStringList(_excludedAppsKey, settings.excludedApps);
    await prefs.setInt(_retentionDaysKey, settings.retentionDays);
    await prefs.setBool(_captureVisibleTextKey, settings.captureVisibleText);
    await prefs.setBool(_captureScreenTextKey, settings.captureScreenText);
    await prefs.setBool(_captureAudioKey, settings.captureAudio);
    await prefs.setBool(_captureBrowserUrlsKey, settings.captureBrowserUrls);
    await prefs.setBool(_captureClipboardKey, settings.captureClipboard);
    await prefs.setBool(
      _allowRemoteSummariesKey,
      settings.allowRemoteSummaries,
    );
    await prefs.setBool(_redactPiiKey, settings.redactPii);
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
