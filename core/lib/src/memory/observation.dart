import '../database/database.dart';

class Observation {
  const Observation({
    required this.id,
    required this.timestamp,
    required this.appName,
    required this.windowTitle,
    this.visibleText,
    this.screenText,
    this.clipboard,
    this.browserUrl,
    this.audioTranscript,
  });

  factory Observation.fromActivity(Activity activity) => Observation(
        id: activity.id,
        timestamp: activity.capturedAt,
        appName: activity.appName,
        windowTitle: activity.windowTitle,
        visibleText: activity.capturedText,
        screenText: activity.capturedScreenText,
        clipboard: activity.capturedClipboard,
        browserUrl: activity.capturedUrl,
        audioTranscript: activity.capturedAudioText,
      );

  final int id;
  final DateTime timestamp;
  final String appName;
  final String windowTitle;
  final String? visibleText;
  final String? screenText;
  final String? clipboard;
  final String? browserUrl;
  final String? audioTranscript;

  Iterable<String> get context => [
        windowTitle,
        if (visibleText != null) visibleText!,
        if (screenText != null) screenText!,
        if (clipboard != null) clipboard!,
        if (browserUrl != null) browserUrl!,
        if (audioTranscript != null) audioTranscript!,
      ].where((value) => value.trim().isNotEmpty);
}
