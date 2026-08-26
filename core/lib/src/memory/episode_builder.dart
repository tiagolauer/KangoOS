import 'episode_repository.dart';
import 'observation.dart';

const defaultEpisodeInactivityGap = Duration(minutes: 30);
const maxEpisodeSummaryLength = 4000;

class EpisodeBuilder {
  const EpisodeBuilder({
    this.inactivityGap = defaultEpisodeInactivityGap,
  });

  final Duration inactivityGap;

  List<NewMemoryEpisode> build(List<Observation> observations) {
    if (observations.isEmpty) return const [];
    final sorted = [...observations]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
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
      ...context.expand((value) =>
          _urlPattern.allMatches(value).map((match) => match.group(0)!)),
    ]);
    final entities = _unique([
      ...urls,
      ...urls.expand(_projects),
      ...context.expand((value) =>
          _filePattern.allMatches(value).map((match) => match.group(0)!)),
    ]);
    final topics = _topics(context);
    final title = observations.length == 1
        ? first.windowTitle
        : '${first.windowTitle} · ${applications.join(', ')}';
    final summary = context
        .map((value) => value.replaceAll(RegExp(r'\s+'), ' ').trim())
        .join('\n');
    return NewMemoryEpisode(
      sourceKey: '${first.id}:${last.id}',
      startedAt: first.timestamp,
      endedAt: last.timestamp,
      title: title,
      summary: summary.length <= maxEpisodeSummaryLength
          ? summary
          : summary.substring(0, maxEpisodeSummaryLength),
      applications: applications,
      urls: urls,
      topics: topics,
      entities: entities,
      sourceActivityIds: observations.map((item) => item.id).toList(),
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
    final ranked = counts.entries.toList()
      ..sort((a, b) {
        final count = b.value.compareTo(a.value);
        return count != 0 ? count : a.key.compareTo(b.key);
      });
    return ranked.take(8).map((entry) => entry.key).toList();
  }

  List<String> _unique(Iterable<String> values) => values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();

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
