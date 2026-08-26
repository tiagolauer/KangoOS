import 'dart:math' as math;

import '../chat/conversation_repository.dart';
import '../database/database.dart';
import '../snippets/snippet_service.dart';
import 'memory_query_engine.dart';
import 'memory_service.dart';

const maxMemoryEvidenceContentLength = 2000;

enum MemoryInvestigationDepth { standard, deep }

enum MemoryEvidenceKind { episode, summary, snippet, conversation }

class MemoryEvidence {
  const MemoryEvidence({
    required this.id,
    required this.kind,
    required this.title,
    required this.content,
    required this.startedAt,
    required this.endedAt,
    this.score = 0,
    this.terms = const [],
  });

  final String id;
  final MemoryEvidenceKind kind;
  final String title;
  final String content;
  final DateTime startedAt;
  final DateTime endedAt;
  final double score;
  final List<String> terms;

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'content': content,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'score': score,
        'terms': terms,
      };
}

class MemorySearchStep {
  const MemorySearchStep({
    required this.tool,
    required this.query,
    required this.resultCount,
  });

  final String tool;
  final String query;
  final int resultCount;

  Map<String, Object?> toJson() => {
        'tool': tool,
        'query': query,
        'resultCount': resultCount,
      };
}

class MemoryReflection {
  const MemoryReflection({
    required this.evidenceCoverage,
    required this.confidence,
    required this.missingEvidence,
    required this.sufficient,
  });

  final double evidenceCoverage;
  final double confidence;
  final List<String> missingEvidence;
  final bool sufficient;

  Map<String, Object?> toJson() => {
        'evidenceCoverage': evidenceCoverage,
        'confidence': confidence,
        'missingEvidence': missingEvidence,
        'sufficient': sufficient,
      };
}

class MemoryInvestigation {
  const MemoryInvestigation({
    required this.query,
    required this.depth,
    required this.evidence,
    required this.steps,
    required this.reflection,
    required this.crossReferences,
    required this.issues,
  });

  final String query;
  final MemoryInvestigationDepth depth;
  final List<MemoryEvidence> evidence;
  final List<MemorySearchStep> steps;
  final MemoryReflection reflection;
  final Map<String, List<String>> crossReferences;
  final List<String> issues;

  String toPrompt() {
    final buffer = StringBuffer(
      'Memory investigation evidence. Cite evidence ids when making factual '
      'claims. Confidence: ${reflection.confidence.toStringAsFixed(2)}.',
    );
    for (final item in evidence) {
      buffer
        ..writeln()
        ..writeln('--- ${item.id} (${item.kind.name}) ---')
        ..writeln('${item.startedAt.toLocal()} - ${item.endedAt.toLocal()}')
        ..writeln(item.title)
        ..writeln(item.content);
    }
    if (reflection.missingEvidence.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(
          'Missing evidence: ${reflection.missingEvidence.join(', ')}.',
        );
    }
    return buffer.toString();
  }

  Map<String, Object?> toJson() => {
        'query': query,
        'depth': depth.name,
        'evidence': evidence.map((item) => item.toJson()).toList(),
        'steps': steps.map((step) => step.toJson()).toList(),
        'reflection': reflection.toJson(),
        'crossReferences': crossReferences,
        'issues': issues,
      };
}

class DeepStudyReport {
  const DeepStudyReport({required this.investigation, required this.markdown});

  final MemoryInvestigation investigation;
  final String markdown;
}

class MemoryAgent {
  const MemoryAgent({
    required this.memory,
    required this.snippets,
    required this.conversations,
  });

  final MemoryService memory;
  final SnippetService snippets;
  final ConversationRepository conversations;

  Future<MemoryInvestigation> investigate(
    String query, {
    MemoryInvestigationDepth depth = MemoryInvestigationDepth.standard,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) throw ArgumentError.value(query, 'query');
    final evidence = <String, MemoryEvidence>{};
    final steps = <MemorySearchStep>[];
    final issues = <String>[];
    final limit = depth == MemoryInvestigationDepth.deep ? 12 : 6;

    await _episodes(
      normalized,
      MemorySearchMode.hybrid,
      limit,
      evidence,
      steps,
      issues,
    );
    await _snippets(normalized, limit, evidence, steps, issues);
    await _summaries(normalized, limit, evidence, steps);
    await _conversations(normalized, limit, evidence, steps);

    var reflection = _reflect(evidence.values.toList(), depth);
    if (!reflection.sufficient || depth == MemoryInvestigationDepth.deep) {
      final expanded = _expandedQuery(normalized, evidence.values);
      await _episodes(
        expanded,
        MemorySearchMode.lexical,
        limit,
        evidence,
        steps,
        issues,
      );
      if (depth == MemoryInvestigationDepth.deep) {
        await _episodes(
          expanded,
          MemorySearchMode.semantic,
          limit,
          evidence,
          steps,
          issues,
        );
      }
      reflection = _reflect(evidence.values.toList(), depth);
    }

    final ranked = evidence.values.toList()
      ..sort((a, b) {
        final score = b.score.compareTo(a.score);
        return score != 0 ? score : b.endedAt.compareTo(a.endedAt);
      });
    return MemoryInvestigation(
      query: normalized,
      depth: depth,
      evidence: ranked
          .take(depth == MemoryInvestigationDepth.deep ? 24 : 12)
          .toList(),
      steps: steps,
      reflection: reflection,
      crossReferences: _crossReferences(ranked),
      issues: issues,
    );
  }

  Future<DeepStudyReport> deepStudy(String query) async {
    final investigation = await investigate(
      query,
      depth: MemoryInvestigationDepth.deep,
    );
    return DeepStudyReport(
      investigation: investigation,
      markdown: _report(investigation),
    );
  }

  Future<void> _episodes(
    String query,
    MemorySearchMode mode,
    int limit,
    Map<String, MemoryEvidence> evidence,
    List<MemorySearchStep> steps,
    List<String> issues,
  ) async {
    final result = await memory.searchEpisodes(query, limit: limit, mode: mode);
    steps.add(MemorySearchStep(
      tool: 'search_memories_${mode.name}',
      query: query,
      resultCount: result.matches.length,
    ));
    if (result.semanticError != null) {
      issues.add('semantic search: ${result.semanticError}');
    }
    for (final match in result.matches) {
      final episode = match.episode;
      evidence['episode:${episode.id}'] = MemoryEvidence(
        id: 'episode:${episode.id}',
        kind: MemoryEvidenceKind.episode,
        title: episode.title,
        content: _content(episode.summary),
        startedAt: episode.startedAt,
        endedAt: episode.endedAt,
        score: match.score,
        terms: [
          ...episode.applications,
          ...episode.topics,
          ...episode.entities,
        ],
      );
    }
  }

  Future<void> _snippets(
    String query,
    int limit,
    Map<String, MemoryEvidence> evidence,
    List<MemorySearchStep> steps,
    List<String> issues,
  ) async {
    List<Snippet> found;
    try {
      found = await snippets.search(
        query,
        mode: SnippetSearchMode.semantic,
        limit: limit,
      );
    } catch (error) {
      issues.add('semantic snippet search: $error');
      found = const [];
    }
    if (found.isEmpty) {
      found = await snippets.search(query, limit: limit);
    }
    steps.add(MemorySearchStep(
      tool: 'search_snippets',
      query: query,
      resultCount: found.length,
    ));
    for (final snippet in found) {
      evidence['snippet:${snippet.id}'] = MemoryEvidence(
        id: 'snippet:${snippet.id}',
        kind: MemoryEvidenceKind.snippet,
        title: snippet.title,
        content: _content(snippet.content),
        startedAt: snippet.createdAt,
        endedAt: snippet.updatedAt,
        score: 0.35,
        terms: [
          ...snippet.tags,
          if (snippet.language != null) snippet.language!,
        ],
      );
    }
  }

  Future<void> _summaries(
    String query,
    int limit,
    Map<String, MemoryEvidence> evidence,
    List<MemorySearchStep> steps,
  ) async {
    final tokens = _tokens(query);
    final recent = await memory.recentSummaries(limit: limit * 3);
    final found = recent
        .where((summary) => _matches(summary.content, tokens))
        .take(limit)
        .toList();
    steps.add(MemorySearchStep(
      tool: 'search_summaries',
      query: query,
      resultCount: found.length,
    ));
    for (final summary in found) {
      evidence['summary:${summary.id}'] = MemoryEvidence(
        id: 'summary:${summary.id}',
        kind: MemoryEvidenceKind.summary,
        title: summary.kind.name,
        content: _content(summary.content),
        startedAt: summary.periodStart,
        endedAt: summary.periodEnd,
        score: 0.3,
        terms: _tokens(summary.content).take(8).toList(),
      );
    }
  }

  Future<void> _conversations(
    String query,
    int limit,
    Map<String, MemoryEvidence> evidence,
    List<MemorySearchStep> steps,
  ) async {
    final found = await conversations.search(query, limit: limit);
    steps.add(MemorySearchStep(
      tool: 'search_conversations',
      query: query,
      resultCount: found.length,
    ));
    for (final message in found) {
      evidence['conversation:${message.id}'] = MemoryEvidence(
        id: 'conversation:${message.id}',
        kind: MemoryEvidenceKind.conversation,
        title: 'Conversation ${message.conversationId} · ${message.role.name}',
        content: _content(message.content),
        startedAt: message.createdAt,
        endedAt: message.createdAt,
        score: 0.25,
        terms: _tokens(message.content).take(8).toList(),
      );
    }
  }

  MemoryReflection _reflect(
    List<MemoryEvidence> evidence,
    MemoryInvestigationDepth depth,
  ) {
    final target = depth == MemoryInvestigationDepth.deep ? 8 : 4;
    final coverage = math.min(1, evidence.length / target);
    final kinds = evidence.map((item) => item.kind).toSet();
    final diversity = math.min(1, kinds.length / 3);
    final confidence = coverage * 0.7 + diversity * 0.3;
    final missing = <String>[
      for (final kind in MemoryEvidenceKind.values)
        if (!kinds.contains(kind)) kind.name,
      if (coverage < 1) 'corroborating evidence',
    ];
    return MemoryReflection(
      evidenceCoverage: coverage.toDouble(),
      confidence: confidence.toDouble(),
      missingEvidence: missing,
      sufficient:
          evidence.length >= 2 && kinds.length >= 2 && confidence >= 0.5,
    );
  }

  String _expandedQuery(String query, Iterable<MemoryEvidence> evidence) {
    final queryTokens = _tokens(query).toSet();
    final counts = <String, int>{};
    for (final term in evidence.expand((item) => item.terms)) {
      final normalized = term.trim().toLowerCase();
      if (normalized.length < 4 || queryTokens.contains(normalized)) continue;
      counts[normalized] = (counts[normalized] ?? 0) + 1;
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) {
        final count = b.value.compareTo(a.value);
        return count != 0 ? count : a.key.compareTo(b.key);
      });
    final expansion = ranked.take(4).map((entry) => entry.key).join(' ');
    return expansion.isEmpty ? query : '$query $expansion';
  }

  Map<String, List<String>> _crossReferences(List<MemoryEvidence> evidence) {
    final references = <String, Set<String>>{};
    for (final item in evidence) {
      for (final term in item.terms.map((value) => value.toLowerCase())) {
        if (term.length < 4) continue;
        references.putIfAbsent(term, () => <String>{}).add(item.id);
      }
    }
    return {
      for (final entry in references.entries)
        if (entry.value.length > 1) entry.key: entry.value.toList()..sort(),
    };
  }

  String _report(MemoryInvestigation investigation) {
    final reflection = investigation.reflection;
    final buffer = StringBuffer()
      ..writeln('# DeepStudy: ${investigation.query}')
      ..writeln()
      ..writeln('## Assessment')
      ..writeln()
      ..writeln('- Confidence: ${reflection.confidence.toStringAsFixed(2)}')
      ..writeln(
        '- Evidence coverage: ${reflection.evidenceCoverage.toStringAsFixed(2)}',
      )
      ..writeln(
        '- Missing evidence: ${reflection.missingEvidence.isEmpty ? 'none' : reflection.missingEvidence.join(', ')}',
      )
      ..writeln()
      ..writeln('## Evidence trail')
      ..writeln();
    for (final item in investigation.evidence) {
      buffer
        ..writeln('### ${item.id} · ${item.title}')
        ..writeln()
        ..writeln(
            '${item.startedAt.toIso8601String()} — ${item.endedAt.toIso8601String()}')
        ..writeln()
        ..writeln(item.content)
        ..writeln();
    }
    buffer
      ..writeln('## Cross-references')
      ..writeln();
    if (investigation.crossReferences.isEmpty) {
      buffer.writeln('No corroborated cross-reference was found.');
    } else {
      for (final entry in investigation.crossReferences.entries) {
        buffer.writeln('- ${entry.key}: ${entry.value.join(', ')}');
      }
    }
    return buffer.toString().trimRight();
  }

  List<String> _tokens(String value) => value
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9_+#.-]+'))
      .where((token) => token.length >= 3)
      .toList();

  bool _matches(String value, List<String> tokens) {
    final normalized = value.toLowerCase();
    return tokens.any(normalized.contains);
  }

  String _content(String value) =>
      value.length <= maxMemoryEvidenceContentLength
          ? value
          : value.substring(0, maxMemoryEvidenceContentLength);
}
