import 'package:kangoos_core/kangoos_core.dart';

const m4SyntheticCorpusVersion = 1;

class M4SearchCase {
  const M4SearchCase({required this.query, required this.expectedKey});

  final String query;
  final String expectedKey;
}

class M4TemporalCase {
  const M4TemporalCase({
    required this.query,
    required this.reference,
    required this.start,
    required this.end,
  });

  final String query;
  final DateTime reference;
  final DateTime start;
  final DateTime end;
}

const m4CorpusTopics = [
  'aurora',
  'boreal',
  'cobalto',
  'duna',
  'eclipse',
  'falcao',
  'galaxia',
  'horizonte',
  'icarus',
  'jade',
  'krypton',
  'lince',
  'miragem',
  'nebula',
  'orion',
  'pulsar',
  'quartzo',
  'radar',
  'saturno',
  'tundra',
  'umbra',
  'vetor',
  'whisky',
  'xenon',
  'zenite',
];

List<M4SearchCase> buildM4SearchCases() => [
  for (var index = 0; index < m4CorpusTopics.length; index++)
    for (final query in [
      m4CorpusTopics[index],
      'projeto ${m4CorpusTopics[index]}',
      'decisão ${m4CorpusTopics[index]}',
      'resultado ${m4CorpusTopics[index]}',
    ])
      M4SearchCase(query: query, expectedKey: 'episode:${index + 1}'),
];

List<M4TemporalCase> buildM4TemporalCases() {
  final cases = <M4TemporalCase>[];
  for (var dayOffset = 0; dayOffset < 25; dayOffset++) {
    final reference = DateTime.utc(
      2026,
      6,
      1,
      15,
    ).add(Duration(days: dayOffset));
    final today = DateTime.utc(reference.year, reference.month, reference.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final currentWeek = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
    final lastWeek = currentWeek.subtract(const Duration(days: 7));
    cases.addAll([
      M4TemporalCase(
        query: 'ontem',
        reference: reference,
        start: yesterday,
        end: today,
      ),
      M4TemporalCase(
        query: 'yesterday',
        reference: reference,
        start: yesterday,
        end: today,
      ),
      M4TemporalCase(
        query: 'semana passada',
        reference: reference,
        start: lastWeek,
        end: currentWeek,
      ),
      M4TemporalCase(
        query: 'last week',
        reference: reference,
        start: lastWeek,
        end: currentWeek,
      ),
    ]);
  }
  return cases;
}

NewMemoryEpisode m4CorpusEpisode(int index, DateTime startedAt) {
  final topic = m4CorpusTopics[index];
  return NewMemoryEpisode(
    sourceKey: 'm4-corpus-v$m4SyntheticCorpusVersion-$topic',
    startedAt: startedAt.add(Duration(minutes: index)),
    endedAt: startedAt.add(Duration(minutes: index + 1)),
    title: 'Projeto $topic',
    summary: 'Projeto $topic com decisão e resultado exclusivos.',
    applications: const ['Benchmark'],
    urls: const [],
    topics: [topic],
    entities: ['project:$topic'],
    sourceActivityIds: const [],
  );
}
