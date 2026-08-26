import 'dart:math' as math;

import 'memory_query_engine.dart';
import 'memory_service.dart';

const maxMemoryEvidenceContentLength = 2000;

enum MemoryInvestigationDepth { standard, deep }

enum MemoryEvidenceKind {
  episode,
  summary,
  durableMemory,
  snippet,
  conversation,
}

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
  const MemoryAgent({required this.memory});

  final MemoryService memory;

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

    await _search(
      normalized,
      MemorySearchMode.hybrid,
      limit,
      evidence,
      steps,
      issues,
    );
    var reflection = _reflect(evidence.values.toList(), depth);
    if (!reflection.sufficient || depth == MemoryInvestigationDepth.deep) {
      final expanded = _expandedQuery(normalized, evidence.values);
      await _search(
        expanded,
        MemorySearchMode.lexical,
        limit,
        evidence,
        steps,
        issues,
      );
      if (depth == MemoryInvestigationDepth.deep) {
        await _search(
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

    final ranked =
        evidence.values.toList()..sort((a, b) {
          final score = b.score.compareTo(a.score);
          return score != 0 ? score : b.endedAt.compareTo(a.endedAt);
        });
    return MemoryInvestigation(
      query: normalized,
      depth: depth,
      evidence:
          ranked
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

  Future<void> _search(
    String query,
    MemorySearchMode mode,
    int limit,
    Map<String, MemoryEvidence> evidence,
    List<MemorySearchStep> steps,
    List<String> issues,
  ) async {
    final result = await memory.searchMemory(query, limit: limit, mode: mode);
    steps.add(
      MemorySearchStep(
        tool: 'search_memory_${mode.name}',
        query: query,
        resultCount: result.evidence.length,
      ),
    );
    if (result.semanticError != null) {
      issues.add('semantic search: ${result.semanticError}');
    }
    for (final item in result.evidence) {
      evidence[item.id] = MemoryEvidence(
        id: item.id,
        kind: _evidenceKind(item.source),
        title: item.title,
        content: _content(item.content),
        startedAt: item.startedAt,
        endedAt: item.endedAt,
        score: item.score,
        terms: [
          ...item.applications,
          ...item.projects,
          ..._tokens(item.content).take(8),
        ],
      );
    }
  }

  MemoryEvidenceKind _evidenceKind(MemoryEvidenceSource source) =>
      switch (source) {
        MemoryEvidenceSource.episode => MemoryEvidenceKind.episode,
        MemoryEvidenceSource.summary => MemoryEvidenceKind.summary,
        MemoryEvidenceSource.durableMemory => MemoryEvidenceKind.durableMemory,
        MemoryEvidenceSource.conversation => MemoryEvidenceKind.conversation,
        MemoryEvidenceSource.snippet => MemoryEvidenceKind.snippet,
      };

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
    final ranked =
        counts.entries.toList()..sort((a, b) {
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
    final buffer =
        StringBuffer()
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
          '${item.startedAt.toIso8601String()} — ${item.endedAt.toIso8601String()}',
        )
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

  List<String> _tokens(String value) =>
      value
          .toLowerCase()
          .split(RegExp(r'[^a-z0-9_+#.-]+'))
          .where((token) => token.length >= 3)
          .toList();

  String _content(String value) =>
      value.length <= maxMemoryEvidenceContentLength
          ? value
          : value.substring(0, maxMemoryEvidenceContentLength);
}
