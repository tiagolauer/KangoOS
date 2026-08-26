import 'package:kangoos_core/kangoos_core.dart';

const m8SyntheticCorpusVersion = 1;
final m8ReferenceTime = DateTime.utc(2026, 8, 26, 18);

class M8CanonicalQuestion {
  const M8CanonicalQuestion({
    required this.question,
    required this.expectedSourceKeys,
  });

  final String question;
  final Set<String> expectedSourceKeys;
}

const m8CanonicalQuestions = [
  M8CanonicalQuestion(
    question: 'O que eu trabalhei ontem?',
    expectedSourceKeys: {'m8-day6-installer'},
  ),
  M8CanonicalQuestion(
    question: 'Em que projeto eu estava quando pesquisei JWT?',
    expectedSourceKeys: {'m8-day3-jwt'},
  ),
  M8CanonicalQuestion(
    question: 'Quando eu mexi pela última vez no sync do KangoOS?',
    expectedSourceKeys: {'m8-day5-sync'},
  ),
  M8CanonicalQuestion(
    question: 'Qual decisão tomamos sobre o banco local?',
    expectedSourceKeys: {'m8-day2-database'},
  ),
  M8CanonicalQuestion(
    question: 'O que eu estava pesquisando antes daquela entrevista?',
    expectedSourceKeys: {'m8-day4-vector-research'},
  ),
  M8CanonicalQuestion(
    question: 'Resuma o que fiz no KangoOS esta semana.',
    expectedSourceKeys: {'m8-day5-sync', 'm8-day6-installer', 'm8-day7-ltm'},
  ),
  M8CanonicalQuestion(
    question: 'Quais problemas apareceram repetidamente no projeto?',
    expectedSourceKeys: {'m8-day3-jwt', 'm8-day5-sync', 'm8-day7-ltm'},
  ),
  M8CanonicalQuestion(
    question: 'Que decisões arquiteturais eu tomei sobre o LTM?',
    expectedSourceKeys: {'m8-day2-database', 'm8-day5-sync', 'm8-day7-ltm'},
  ),
];

List<NewMemoryEpisode> buildM8Corpus() => [
  _episode(
    sourceKey: 'm8-day1-cloud-plan',
    day: 20,
    hour: 14,
    title: 'Plano inicial do banco LTM',
    summary:
        'Nunca usar banco local para o LTM; o plano inicial era banco na nuvem.',
    decisions: const ['Banco do LTM seria remoto.'],
  ),
  _episode(
    sourceKey: 'm8-day2-database',
    day: 21,
    hour: 10,
    title: 'Reunião de arquitetura do KangoOS',
    summary:
        'Decisão final sobre o banco local do KangoOS e do LTM após a reunião.',
    decisions: const [
      'Usar banco local SQLite criptografado com SQLCipher.',
      'Manter o LTM local-first; sincronização externa fica desativada por padrão.',
    ],
    technologies: const ['SQLite', 'SQLCipher'],
  ),
  _episode(
    sourceKey: 'm8-day3-jwt',
    day: 22,
    hour: 9,
    title: 'Pesquisa JWT no projeto Atlas',
    summary:
        'No projeto Atlas pesquisei JWT. Problemas de OCR duplicado apareceram repetidamente no projeto.',
    entities: const ['project:Atlas'],
    technologies: const ['JWT', 'OCR'],
  ),
  _episode(
    sourceKey: 'm8-day4-vector-research',
    day: 23,
    hour: 9,
    title: 'Pesquisa antes da entrevista',
    summary:
        'Antes da entrevista pesquisei índice vetorial e busca semântica para o KangoOS.',
    technologies: const ['vector index', 'semantic search'],
  ),
  _episode(
    sourceKey: 'm8-day4-interview',
    day: 23,
    hour: 11,
    title: 'Entrevista técnica',
    summary: 'Participei daquela entrevista sobre sistemas locais.',
  ),
  _episode(
    sourceKey: 'm8-day5-sync',
    day: 24,
    hour: 16,
    title: 'Última alteração no sync do KangoOS',
    summary:
        'Mexi pela última vez no sync do KangoOS. Problemas de OCR duplicado apareceram repetidamente no projeto.',
    decisions: const ['O sync do LTM permanece manual e opt-in.'],
    technologies: const ['sync', 'OCR'],
  ),
  _episode(
    sourceKey: 'm8-day6-installer',
    day: 25,
    hour: 15,
    title: 'Trabalho de ontem no KangoOS',
    summary:
        'Ontem trabalhei no instalador, na bandeja do Windows e no upgrade criptografado do KangoOS.',
    technologies: const ['Inno Setup', 'Windows'],
  ),
  _episode(
    sourceKey: 'm8-day7-ltm',
    day: 26,
    hour: 10,
    title: 'Hardening da arquitetura LTM',
    summary:
        'Revisei a arquitetura LTM do KangoOS. Problemas de OCR duplicado apareceram repetidamente no projeto.',
    decisions: const [
      'Expor Desktop e MCP pelo mesmo MemoryAgent.',
      'Registrar métricas locais sem conteúdo pessoal.',
    ],
    technologies: const ['LTM', 'MCP', 'OCR'],
  ),
];

Future<Map<String, int>> seedM8Corpus(EpisodeRepository repository) async {
  final ids = <String, int>{};
  for (final episode in buildM8Corpus()) {
    ids[episode.sourceKey] = await repository.create(episode);
  }
  return ids;
}

Future<void> seedM8Corroboration(SummaryRepository repository) async {
  for (final episode in buildM8Corpus()) {
    await repository.create(
      NewActivitySummary(
        kind: SummaryKind.daily,
        periodStart: episode.startedAt,
        periodEnd: episode.endedAt,
        content: [
          episode.title,
          episode.summary,
          ...episode.decisions,
          ...episode.technologies,
          ...episode.entities,
        ].join('\n'),
      ),
    );
  }
}

NewMemoryEpisode _episode({
  required String sourceKey,
  required int day,
  required int hour,
  required String title,
  required String summary,
  List<String> decisions = const [],
  List<String> technologies = const [],
  List<String> entities = const ['project:KangoOS'],
}) {
  final startedAt = DateTime.utc(2026, 8, day, hour);
  return NewMemoryEpisode(
    sourceKey: sourceKey,
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(hours: 1)),
    title: title,
    summary: summary,
    applications: const ['Visual Studio Code'],
    urls: const [],
    topics: const ['M8', 'hardening'],
    entities: entities,
    sourceActivityIds: const [],
    decisions: decisions,
    technologies: technologies,
  );
}
