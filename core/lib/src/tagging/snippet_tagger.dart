import 'dart:convert';

import '../llm/llm_provider.dart';

const _maxTags = 6;
const _maxTagLength = 30;

class SnippetTagger {
  const SnippetTagger();

  Future<List<String>> suggestTags({
    required LlmProvider provider,
    required String title,
    required String content,
    String? language,
  }) async {
    final buffer = StringBuffer();
    await for (final chunk in provider.chat([
      LlmMessage(
          role: LlmRole.user, content: _buildPrompt(title, content, language)),
    ])) {
      buffer.write(chunk);
    }
    return _parseTags(buffer.toString());
  }

  String _buildPrompt(String title, String content, String? language) {
    final buffer = StringBuffer(
      'Suggest $_maxTags or fewer short, lowercase tags for this code snippet '
      "(single words or short hyphenated phrases, e.g. 'dart', 'string-manipulation'). "
      'Respond with ONLY a JSON array of strings, nothing else — no explanation, no markdown.',
    );
    buffer.writeln();
    buffer.writeln('Title: $title');
    if (language != null && language.isNotEmpty) {
      buffer.writeln('Language: $language');
    }
    buffer.writeln('Code:');
    buffer.write(content);
    return buffer.toString();
  }

  List<String> _parseTags(String raw) {
    final jsonArray = RegExp(r'\[[\s\S]*\]').firstMatch(raw)?.group(0);
    if (jsonArray != null) {
      try {
        final decoded = jsonDecode(jsonArray);
        if (decoded is List) {
          return _clean(decoded.map((tag) => tag.toString()));
        }
      } catch (_) {
        // Fall through to the plain-text fallback below.
      }
    }
    return _clean(raw.split(RegExp(r'[,\n]')));
  }

  List<String> _clean(Iterable<String> tags) {
    final seen = <String>{};
    final cleaned = <String>[];
    for (final raw in tags) {
      final tag = raw.replaceAll(RegExp(r'[^\w\s-]'), '').trim().toLowerCase();
      if (tag.isEmpty || tag.length > _maxTagLength || !seen.add(tag)) continue;
      cleaned.add(tag);
      if (cleaned.length == _maxTags) break;
    }
    return cleaned;
  }
}
