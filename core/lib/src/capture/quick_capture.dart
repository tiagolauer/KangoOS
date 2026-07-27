import 'package:drift/drift.dart' show Value;

import '../database/database.dart';

const maxQuickCaptureTitleLength = 60;

final _languageSignals = <String, List<RegExp>>{
  'dart': [
    RegExp(r'^\s*import\s+.dart:', multiLine: true),
    RegExp(r'\bWidget\s+build\s*\(BuildContext'),
    RegExp(r'^\s*(final|var)\s+\w+\s*=', multiLine: true),
  ],
  'python': [
    RegExp(r'^\s*def\s+\w+\s*\(.*\)\s*:', multiLine: true),
    RegExp(r'^\s*from\s+[\w.]+\s+import\s', multiLine: true),
    RegExp(r'^\s*print\(', multiLine: true),
  ],
  'javascript': [
    RegExp(r'^\s*(const|let)\s+\w+\s*=', multiLine: true),
    RegExp(r'\bfunction\s+\w+\s*\('),
    RegExp(r'\bconsole\.log\('),
  ],
  'sql': [
    RegExp(r'^\s*select\s+.+\s+from\s', multiLine: true, caseSensitive: false),
    RegExp(r'^\s*(insert\s+into|update|delete\s+from)\s',
        multiLine: true, caseSensitive: false),
  ],
  'json': [
    RegExp(r'^\s*[\{\[][\s\S]*[\}\]]\s*$'),
  ],
  'yaml': [
    RegExp(r'^\s*[\w-]+:\s*$', multiLine: true),
    RegExp(r'^\s*-\s+\w+:\s', multiLine: true),
  ],
  'html': [
    RegExp(r'<(html|div|span|p|body)\b', caseSensitive: false),
  ],
  'css': [
    RegExp(r'^\s*[.#]?[\w-]+\s*\{[^}]*:[^}]*;', multiLine: true),
  ],
  'shell': [
    RegExp(r'^#!/.*\b(bash|sh|zsh)\b', multiLine: true),
    RegExp(r'^\s*(sudo|apt|npm|git|docker)\s+\w+', multiLine: true),
  ],
};

String? detectSnippetLanguage(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty) return null;

  var best = <String, int>{};
  for (final entry in _languageSignals.entries) {
    final hits = entry.value.where((signal) => signal.hasMatch(trimmed)).length;
    if (hits > 0) best[entry.key] = hits;
  }
  if (best.isEmpty) return null;

  final ranked = best.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return ranked.first.key;
}

String quickCaptureTitle(String content) {
  final firstLine = content
      .trim()
      .split('\n')
      .map((line) => line.trim())
      .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  if (firstLine.length <= maxQuickCaptureTitleLength) return firstLine;
  return '${firstLine.substring(0, maxQuickCaptureTitleLength).trimRight()}...';
}

SnippetsCompanion buildQuickCapture({
  required String clipboard,
  String? sourceApp,
}) {
  final content = clipboard.trim();
  final language = detectSnippetLanguage(content);
  final source = sourceApp?.trim().toLowerCase();

  return SnippetsCompanion.insert(
    title: quickCaptureTitle(content),
    content: content,
    language: Value(language),
    tags: Value([
      'quick-capture',
      if (source != null && source.isNotEmpty) source,
    ]),
  );
}
