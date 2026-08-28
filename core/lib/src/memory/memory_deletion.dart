enum MemoryModality { vision, clipboard, browser, audio, metadata }

enum MemoryType {
  activity,
  episode,
  automaticSummary,
  manualSummary,
  durableMemory,
}

const defaultDeletableMemoryTypes = {
  MemoryType.activity,
  MemoryType.episode,
  MemoryType.automaticSummary,
};

class MemoryDeletionFilter {
  const MemoryDeletionFilter({
    this.start,
    this.end,
    this.activityIds = const {},
    this.applications = const {},
    this.modalities = const {},
    this.memoryTypes = defaultDeletableMemoryTypes,
  });

  final DateTime? start;
  final DateTime? end;
  final Set<int> activityIds;
  final Set<String> applications;
  final Set<MemoryModality> modalities;
  final Set<MemoryType> memoryTypes;

  void validate() {
    if (start != null && end != null && !start!.isBefore(end!)) {
      throw ArgumentError.value(end, 'end', 'must be after start');
    }
    if (memoryTypes.isEmpty) {
      throw ArgumentError.value(
        memoryTypes,
        'memoryTypes',
        'must not be empty',
      );
    }
  }
}

class MemoryDeletionPreview {
  const MemoryDeletionPreview({
    required this.activities,
    required this.episodes,
    required this.summaries,
    required this.embeddings,
  });

  final int activities;
  final int episodes;
  final int summaries;
  final int embeddings;

  int get total => activities + episodes + summaries;
}

class MemoryDeletionResult extends MemoryDeletionPreview {
  const MemoryDeletionResult({
    required super.activities,
    required super.episodes,
    required super.summaries,
    required super.embeddings,
  });
}
