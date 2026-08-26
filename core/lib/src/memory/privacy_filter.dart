import 'activity_repository.dart';

const redactedValue = '[REDACTED]';

class PrivacyFilter {
  const PrivacyFilter({this.redactPii = false});

  final bool redactPii;

  String? filter(String? value) {
    if (value == null || value.isEmpty) return value;
    var filtered = value;
    for (final pattern in _secretPatterns) {
      filtered = filtered.replaceAll(pattern, redactedValue);
    }
    filtered = filtered.replaceAllMapped(
      _bearerSecret,
      (match) => '${match.group(1)}$redactedValue',
    );
    filtered = filtered.replaceAllMapped(
      _assignedSecret,
      (match) => '${match.group(1)}$redactedValue',
    );
    if (redactPii) {
      for (final pattern in _piiPatterns) {
        filtered = filtered.replaceAll(pattern, redactedValue);
      }
    }
    return filtered;
  }

  NewActivity filterActivity(NewActivity activity) => NewActivity(
        appName: activity.appName,
        windowTitle: filter(activity.windowTitle) ?? activity.windowTitle,
        capturedText: filter(activity.capturedText),
        capturedUrl: filter(activity.capturedUrl),
        capturedClipboard: filter(activity.capturedClipboard),
        capturedScreenText: filter(activity.capturedScreenText),
        capturedAudioText: filter(activity.capturedAudioText),
        capturedAt: activity.capturedAt,
      );
}

final _secretPatterns = <RegExp>[
  RegExp(
    r'-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----',
  ),
  RegExp(r'\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b'),
  RegExp(r'\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b'),
  RegExp(r'\bAKIA[0-9A-Z]{16}\b'),
  RegExp(r'\bsk-[A-Za-z0-9_-]{16,}\b'),
];

final _assignedSecret = RegExp(
  r'''((?:api[_-]?key|token|access[_-]?token|auth[_-]?token|password|passwd|secret|aws[_-]?secret[_-]?access[_-]?key)\s*[:=]\s*["']?)[^\s,"';&]+''',
  caseSensitive: false,
);

final _bearerSecret = RegExp(
  r'\b(Bearer\s+)[A-Za-z0-9._~+/=-]{8,}',
  caseSensitive: false,
);

final _piiPatterns = <RegExp>[
  RegExp(r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b', caseSensitive: false),
  RegExp(r'\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b'),
  RegExp(r'\b(?:\d[ -]*?){13,19}\b'),
  RegExp(r'(?<!\d)(?:\+?55\s*)?\(?\d{2}\)?\s*9?\d{4}[- ]?\d{4}\b'),
];
