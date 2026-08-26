import 'dart:convert';

import '../database/tables/memory_episodes_table.dart';
import '../llm/llm_provider.dart';
import '../llm/llm_stream.dart';
import 'episode_repository.dart';

const maxEnrichedItems = 12;
const maxEnrichedItemLength = 500;

class MemoryEpisodeEnricher {
  const MemoryEpisodeEnricher({required this.provider, required this.modelId});

  final LlmProvider provider;
  final String modelId;

  Future<NewMemoryEpisode> enrich(NewMemoryEpisode episode) async {
    final response = await collectLlmReply(
      provider.chat([
        const LlmMessage(
          role: LlmRole.system,
          content:
              'Responda sempre em português do Brasil (PT-BR). Extraia '
              'somente fatos sustentados pelo contexto. Retorne apenas JSON '
              'válido, sem markdown e sem texto adicional.',
        ),
        LlmMessage(role: LlmRole.user, content: _prompt(episode)),
      ]),
    );
    final json = _decodeObject(response);
    final summary = _string(json, 'summary');
    final confidence = _confidence(json['confidence']);
    final decisions = _merge(episode.decisions, _strings(json, 'decisions'));
    final actionItems = _merge(
      episode.actionItems,
      _strings(json, 'actionItems'),
    );
    final technologies = _merge(
      episode.technologies,
      _strings(json, 'technologies'),
    );
    final entities = _merge(episode.entities, [
      ..._prefixed(json, 'people', 'person'),
      ..._prefixed(json, 'projects', 'project'),
      ..._prefixed(json, 'files', 'file'),
      ..._prefixed(json, 'relations', 'relation'),
    ]);
    return episode.copyWith(
      summary: summary.isEmpty ? episode.summary : summary,
      decisions: decisions,
      actionItems: actionItems,
      technologies: technologies,
      entities: entities,
      confidence: confidence,
      formationStatus: MemoryFormationStatus.enriched,
      formationModelId: modelId,
    );
  }

  String _prompt(NewMemoryEpisode episode) => jsonEncode({
    'task': 'Enriqueça esta memória sem inventar informações.',
    'schema': {
      'summary': 'string em PT-BR',
      'confidence': 'number entre 0 e 1',
      'decisions': ['string'],
      'actionItems': ['string'],
      'technologies': ['string'],
      'people': ['string'],
      'projects': ['string'],
      'files': ['string'],
      'relations': ['string'],
    },
    'memory': {
      'what': episode.summary,
      'when': {
        'start': episode.startedAt.toIso8601String(),
        'end': episode.endedAt.toIso8601String(),
      },
      'where': {'applications': episode.applications, 'urls': episode.urls},
      'topics': episode.topics,
      'entities': episode.entities,
      'decisions': episode.decisions,
      'actionItems': episode.actionItems,
      'technologies': episode.technologies,
    },
  });

  Map<String, Object?> _decodeObject(String response) {
    final trimmed = response.trim();
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start < 0 || end < start) {
      throw const FormatException('Memory enrichment did not return JSON.');
    }
    final Object? decoded = jsonDecode(trimmed.substring(start, end + 1));
    if (decoded is! Map) {
      throw const FormatException('Memory enrichment JSON must be an object.');
    }
    return decoded.cast<String, Object?>();
  }

  String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return '';
    if (value is! String) {
      throw FormatException('Memory enrichment field "$key" must be text.');
    }
    return _limit(value);
  }

  List<String> _strings(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) return const [];
    if (value is! List || value.any((item) => item is! String)) {
      throw FormatException('Memory enrichment field "$key" must be a list.');
    }
    return value
        .cast<String>()
        .map(_limit)
        .where((item) => item.isNotEmpty)
        .take(maxEnrichedItems)
        .toList();
  }

  List<String> _prefixed(
    Map<String, Object?> json,
    String key,
    String prefix,
  ) => _strings(json, key).map((value) => '$prefix:$value').toList();

  double _confidence(Object? value) {
    if (value is! num || !value.toDouble().isFinite) {
      throw const FormatException(
        'Memory enrichment confidence must be a number.',
      );
    }
    return value.toDouble().clamp(0, 1).toDouble();
  }

  List<String> _merge(Iterable<String> first, Iterable<String> second) =>
      {
        ...first.map(_limit).where((value) => value.isNotEmpty),
        ...second.map(_limit).where((value) => value.isNotEmpty),
      }.take(maxEnrichedItems).toList();

  String _limit(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= maxEnrichedItemLength
        ? normalized
        : normalized.substring(0, maxEnrichedItemLength);
  }
}
