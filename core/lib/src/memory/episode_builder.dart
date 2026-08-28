import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'episode_repository.dart';
import 'observation.dart';

const defaultEpisodeInactivityGap = Duration(minutes: 30);
const maxEpisodeSummaryLength = 4000;
const maxEpisodeDetailLength = 500;
const maxEpisodeDetails = 8;

class EpisodeBuilder {
  const EpisodeBuilder({this.inactivityGap = defaultEpisodeInactivityGap});

  final Duration inactivityGap;

  List<NewMemoryEpisode> build(List<Observation> observations) {
    if (observations.isEmpty) return const [];
    final sorted = [...observations]..sort((a, b) {
      final timestamp = a.timestamp.compareTo(b.timestamp);
      return timestamp != 0 ? timestamp : a.id.compareTo(b.id);
    });
    final groups = <List<Observation>>[];
    var current = <Observation>[sorted.first];
    for (final observation in sorted.skip(1)) {
      final previous = current.last;
      if (observation.timestamp.difference(previous.timestamp) >
          inactivityGap) {
        groups.add(current);
        current = <Observation>[];
      }
      current.add(observation);
    }
    groups.add(current);
    return groups.map(_episode).toList();
  }

  NewMemoryEpisode _episode(List<Observation> observations) {
    final first = observations.first;
    final last = observations.last;
    final applications = _unique(observations.map((item) => item.appName));
    final context = _unique(observations.expand((item) => item.context));
    final urls = _unique([
      ...observations.map((item) => item.browserUrl).whereType<String>(),
      ...context.expand(
        (value) =>
            _urlPattern.allMatches(value).map((match) => match.group(0)!),
      ),
    ]);
    final entities = _unique([
      ...urls,
      ...urls.expand(_projects),
      ...context.expand(
        (value) => _filePattern
            .allMatches(value)
            .map((match) => 'file:${match.group(0)!}'),
      ),
    ]);
    final topics = _topics(context);
    final decisions = _matchingContext(context, _decisionPattern);
    final actionItems = _matchingContext(context, _actionItemPattern);
    final technologies = _technologies(context, entities);
    final title =
        observations.length == 1
            ? first.windowTitle
            : '${first.windowTitle} · ${applications.join(', ')}';
    final rawSummary = context
        .map((value) => value.replaceAll(RegExp(r'\s+'), ' ').trim())
        .join('\n');
    final summary =
        rawSummary.length <= maxEpisodeSummaryLength
            ? rawSummary
            : rawSummary.substring(0, maxEpisodeSummaryLength);
    final sourceKey = '${first.id}:${last.id}';
    final sourceActivityIds = observations.map((item) => item.id).toList();
    final contentHash =
        sha256
            .convert(
              utf8.encode(
                jsonEncode({
                  'version': currentMemoryFormationVersion,
                  'sourceKey': sourceKey,
                  'startedAt': first.timestamp.toUtc().toIso8601String(),
                  'endedAt': last.timestamp.toUtc().toIso8601String(),
          'title': title,
          'summary': summary,
          'sourceContext': rawSummary,
                  'applications': applications,
                  'urls': urls,
                  'topics': topics,
                  'entities': entities,
                  'decisions': decisions,
                  'actionItems': actionItems,
                  'technologies': technologies,
                  'sourceActivityIds': sourceActivityIds,
                }),
              ),
            )
            .toString();
    return NewMemoryEpisode(
      sourceKey: sourceKey,
      startedAt: first.timestamp,
      endedAt: last.timestamp,
      title: title,
      summary: summary,
      applications: applications,
      urls: urls,
      topics: topics,
      entities: entities,
      decisions: decisions,
      actionItems: actionItems,
      technologies: technologies,
      sourceActivityIds: sourceActivityIds,
      contentHash: contentHash,
    );
  }

  List<String> _topics(List<String> context) {
    final counts = <String, int>{};
    for (final token in context
        .join(' ')
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9_+#.-]+'))
        .where((token) => token.length >= 4 && !_stopWords.contains(token))) {
      counts[token] = (counts[token] ?? 0) + 1;
    }
    final ranked =
        counts.entries.toList()..sort((a, b) {
          final count = b.value.compareTo(a.value);
          return count != 0 ? count : a.key.compareTo(b.key);
        });
    return ranked.take(8).map((entry) => entry.key).toList();
  }

  List<String> _unique(Iterable<String> values) =>
      values
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();

  List<String> _matchingContext(List<String> context, RegExp pattern) =>
      _unique(
        context.where(pattern.hasMatch).map((value) {
          final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
          return normalized.length <= maxEpisodeDetailLength
              ? normalized
              : normalized.substring(0, maxEpisodeDetailLength);
        }),
      ).take(maxEpisodeDetails).toList();

  List<String> _technologies(List<String> context, List<String> entities) {
    final text = context.join(' ').toLowerCase();
    return _unique([
      for (final entry in _technologyPatterns.entries)
        if (entry.value.hasMatch(text)) entry.key,
      for (final entity in entities)
        if (entity.startsWith('file:'))
          if (_technologyByExtension[_extension(entity)] case final name?) name,
    ]);
  }

  String _extension(String value) {
    final match = RegExp(
      r'\.([a-z0-9]+)$',
      caseSensitive: false,
    ).firstMatch(value);
    return match?.group(1)?.toLowerCase() ?? '';
  }

  Iterable<String> _projects(String url) sync* {
    final match = _githubProjectPattern.firstMatch(url);
    if (match == null) return;
    final repository = match.group(2)!.replaceFirst(RegExp(r'\.git$'), '');
    yield 'project:${match.group(1)!.toLowerCase()}/${repository.toLowerCase()}';
  }
}

final _urlPattern = RegExp(r'https?://[^\s)\]}>]+', caseSensitive: false);
final _githubProjectPattern = RegExp(
  r'https?://(?:www\.)?github\.com/([^/\s]+)/([^/#?\s]+)',
  caseSensitive: false,
);
final _filePattern = RegExp(
  r'\b[\w.-]+\.(?:dart|ts|tsx|js|jsx|py|rs|go|java|kt|swift|sql|md|yaml|yml|json)\b',
  caseSensitive: false,
);
final _decisionPattern = RegExp(
  r'\b(?:decid\w*|decision|agreed|approved|escolh\w*|defin\w*)\b',
  caseSensitive: false,
);
final _actionItemPattern = RegExp(
  r'\b(?:todo|to-do|pending|pendente|pr[oó]ximo passo|follow-up|precisa|deve)\b',
  caseSensitive: false,
);
final _technologyPatterns = <String, RegExp>{
  'Dart': RegExp(r'\bdart\b|\.dart\b'),
  'Flutter': RegExp(r'\bflutter\b'),
  'TypeScript': RegExp(r'\btypescript\b|\.(?:ts|tsx)\b'),
  'JavaScript': RegExp(r'\bjavascript\b|\.(?:js|jsx)\b'),
  'Python': RegExp(r'\bpython\b|\.py\b'),
  'Rust': RegExp(r'\brust\b|\.rs\b'),
  'SQL': RegExp(r'\bsql\b|\.sql\b'),
  'Docker': RegExp(r'\bdocker\b'),
  'Git': RegExp(r'\bgit(?:hub|lab)?\b'),
};
const _technologyByExtension = <String, String>{
  'dart': 'Dart',
  'ts': 'TypeScript',
  'tsx': 'TypeScript',
  'js': 'JavaScript',
  'jsx': 'JavaScript',
  'py': 'Python',
  'rs': 'Rust',
  'sql': 'SQL',
};
const _stopWords = {
  'with',
  'from',
  'this',
  'that',
  'para',
  'como',
  'uma',
  'the',
  'and',
  'http',
  'https',
};
