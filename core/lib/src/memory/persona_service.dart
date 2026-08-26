import '../database/database.dart';
import '../database/tables/activity_summaries_table.dart';
import 'persona_repository.dart';
import 'privacy_filter.dart';
import 'summary_repository.dart';

const maxLocalPersonaCharacters = 4000;
const recurringMemoryLabelPrefix = 'Memória recorrente:';

class PersonaService {
  const PersonaService({
    required this.repository,
    required this.summaries,
    this.privacyFilter = const PrivacyFilter(),
  });

  final PersonaRepository repository;
  final SummaryRepository summaries;
  final PrivacyFilter privacyFilter;

  Future<LocalPersona?> load() async {
    final persona = await repository.load();
    if (persona == null) return null;
    if (persona.sourceSummaryIds.isEmpty) {
      await repository.delete();
      return null;
    }
    final sources = await summaries.byIds(persona.sourceSummaryIds);
    final validIds = sources.where(_isRecurringDurable).map((item) => item.id);
    if (validIds.toSet().length != persona.sourceSummaryIds.toSet().length) {
      await repository.delete();
      return null;
    }
    return persona;
  }

  Future<LocalPersona?> generate() async {
    final recurring =
        (await summaries.all()).where(_isRecurringDurable).toList()
          ..sort((left, right) {
            final byDate = right.periodEnd.compareTo(left.periodEnd);
            return byDate != 0 ? byDate : right.id.compareTo(left.id);
          });
    if (recurring.isEmpty) {
      await repository.delete();
      return null;
    }
    final seen = <String>{};
    final lines = <String>[];
    final sourceSummaryIds = <int>[];
    for (final summary in recurring) {
      final label = _recurringLabel(summary.content);
      if (label == null || !seen.add(label.toLowerCase())) continue;
      final line = '- $label';
      final candidate = [...lines, line].join('\n');
      if (candidate.length > maxLocalPersonaCharacters) continue;
      lines.add(line);
      sourceSummaryIds.add(summary.id);
    }
    if (lines.isEmpty) return null;
    final content = _filteredContent(lines.join('\n'));
    return repository.save(
      enabled: true,
      content: content,
      sourceSummaryIds: sourceSummaryIds,
    );
  }

  Future<LocalPersona> edit(String content) async {
    final persona = await _requiredPersona();
    return repository.save(
      enabled: persona.enabled,
      content: _filteredContent(content),
      sourceSummaryIds: persona.sourceSummaryIds,
    );
  }

  Future<LocalPersona> setEnabled(bool enabled) async {
    final persona = await _requiredPersona();
    return repository.save(
      enabled: enabled,
      content: persona.content,
      sourceSummaryIds: persona.sourceSummaryIds,
    );
  }

  Future<int> delete() => repository.delete();

  Future<String?> promptContent() async {
    final persona = await load();
    if (persona == null || !persona.enabled) return null;
    return persona.content;
  }

  Future<LocalPersona> _requiredPersona() async {
    final persona = await load();
    if (persona == null) throw StateError('Local persona does not exist.');
    return persona;
  }

  bool _isRecurringDurable(ActivitySummary summary) =>
      summary.kind == SummaryKind.durable &&
      summary.content.startsWith(automaticDurableMemoryPrefix);

  String? _recurringLabel(String content) {
    for (final line in content.split('\n')) {
      final normalized = line.trim();
      if (!normalized.startsWith(recurringMemoryLabelPrefix)) continue;
      final label =
          normalized.substring(recurringMemoryLabelPrefix.length).trim();
      if (label.isNotEmpty) return label;
    }
    return null;
  }

  String _filteredContent(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > maxLocalPersonaCharacters) {
      throw ArgumentError.value(
        value,
        'content',
        'must contain between 1 and $maxLocalPersonaCharacters characters',
      );
    }
    final filtered = privacyFilter.filter(normalized) ?? '';
    if (filtered.isEmpty) {
      throw ArgumentError.value(value, 'content', 'must not be empty');
    }
    return filtered;
  }
}
