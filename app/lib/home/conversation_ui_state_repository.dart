import 'dart:convert';
import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

const maxChatAttachmentRoots = 8;
const maxChatAttachmentFiles = 20;
const maxChatAttachmentFileBytes = 128 * 1024;
const maxChatAttachmentContextBytes = 512 * 1024;

class ConversationUiState {
  const ConversationUiState({
    this.filters = const MemorySearchFilters(),
    this.attachmentPaths = const [],
    this.evidence = const [],
  });

  final MemorySearchFilters filters;
  final List<String> attachmentPaths;
  final List<MemoryEvidence> evidence;

  ConversationUiState copyWith({
    MemorySearchFilters? filters,
    List<String>? attachmentPaths,
    List<MemoryEvidence>? evidence,
  }) => ConversationUiState(
    filters: filters ?? this.filters,
    attachmentPaths: attachmentPaths ?? this.attachmentPaths,
    evidence: evidence ?? this.evidence,
  );
}

class ConversationUiStateRepository {
  static const _keyPrefix = 'conversation_ui_state_';

  Future<ConversationUiState> load(int conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('$_keyPrefix$conversationId');
    if (encoded == null) return const ConversationUiState();
    try {
      final decoded = jsonDecode(encoded) as Object?;
      if (decoded is! Map<Object?, Object?>) {
        throw const FormatException('Conversation UI state must be an object.');
      }
      final json = Map<String, Object?>.from(decoded);
      return ConversationUiState(
        filters: _filtersFromJson(
          Map<String, Object?>.from(json['filters']! as Map<Object?, Object?>),
        ),
        attachmentPaths:
            (json['attachmentPaths'] as List<Object?>? ?? const [])
                .whereType<String>()
                .toList(),
        evidence:
            (json['evidence'] as List<Object?>? ?? const [])
                .whereType<Map<Object?, Object?>>()
                .map(
                  (item) =>
                      MemoryEvidence.fromJson(Map<String, Object?>.from(item)),
                )
                .toList(),
      );
    } on FormatException {
      await prefs.remove('$_keyPrefix$conversationId');
      return const ConversationUiState();
    } on TypeError {
      await prefs.remove('$_keyPrefix$conversationId');
      return const ConversationUiState();
    } on ArgumentError {
      await prefs.remove('$_keyPrefix$conversationId');
      return const ConversationUiState();
    }
  }

  Future<void> save(int conversationId, ConversationUiState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_keyPrefix$conversationId',
      jsonEncode({
        'filters': _filtersToJson(state.filters),
        'attachmentPaths': state.attachmentPaths,
        'evidence': state.evidence.map((item) => item.toJson()).toList(),
      }),
    );
  }

  Future<void> delete(int conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$conversationId');
  }
}

Map<String, Object?> _filtersToJson(MemorySearchFilters filters) => {
  'sources': filters.sources.map((item) => item.name).toList(),
  'applications': filters.applications.toList(),
  'modalities': filters.modalities.map((item) => item.name).toList(),
  'projects': filters.projects.toList(),
  if (filters.start != null) 'start': filters.start!.toIso8601String(),
  if (filters.end != null) 'end': filters.end!.toIso8601String(),
};

MemorySearchFilters _filtersFromJson(Map<String, Object?> json) =>
    MemorySearchFilters(
      sources:
          (json['sources'] as List<Object?>? ?? const [])
              .whereType<String>()
              .map(MemoryEvidenceSource.values.byName)
              .toSet(),
      applications:
          (json['applications'] as List<Object?>? ?? const [])
              .whereType<String>()
              .toSet(),
      modalities:
          (json['modalities'] as List<Object?>? ?? const [])
              .whereType<String>()
              .map(MemoryModality.values.byName)
              .toSet(),
      projects:
          (json['projects'] as List<Object?>? ?? const [])
              .whereType<String>()
              .toSet(),
      start:
          json['start'] == null
              ? null
              : DateTime.parse(json['start']! as String),
      end: json['end'] == null ? null : DateTime.parse(json['end']! as String),
    );

Future<String?> buildAttachmentContext(List<String> roots) async {
  final files = <File>[];
  final scanErrors = <Map<String, Object?>>[];
  for (final root in roots.take(maxChatAttachmentRoots)) {
    final FileSystemEntityType type;
    try {
      type = await FileSystemEntity.type(root, followLinks: false);
    } on FileSystemException catch (error) {
      scanErrors.add({'path': root, 'error': error.message});
      continue;
    }
    if (type == FileSystemEntityType.file && _isTextFile(root)) {
      files.add(File(root));
    } else if (type == FileSystemEntityType.directory) {
      try {
        await for (final entity in Directory(
          root,
        ).list(recursive: true, followLinks: false)) {
          if (entity is File && _isTextFile(entity.path)) files.add(entity);
          if (files.length >= maxChatAttachmentFiles) break;
        }
      } on FileSystemException catch (error) {
        scanErrors.add({'path': root, 'error': error.message});
        continue;
      }
    }
    if (files.length >= maxChatAttachmentFiles) break;
  }
  if (files.isEmpty && scanErrors.isEmpty) return null;
  files.sort((left, right) => left.path.compareTo(right.path));

  final documents = <Map<String, Object?>>[...scanErrors];
  var usedBytes = 0;
  for (final file in files.take(maxChatAttachmentFiles)) {
    if (usedBytes >= maxChatAttachmentContextBytes) break;
    try {
      final remaining = maxChatAttachmentContextBytes - usedBytes;
      final limit =
          remaining < maxChatAttachmentFileBytes
              ? remaining
              : maxChatAttachmentFileBytes;
      final bytes = await file
          .openRead(0, limit)
          .fold<List<int>>(<int>[], (buffer, chunk) => buffer..addAll(chunk));
      usedBytes += bytes.length;
      documents.add({
        'path': file.path,
        'content': utf8.decode(bytes, allowMalformed: true),
      });
    } on FileSystemException catch (error) {
      documents.add({'path': file.path, 'error': error.message});
    }
  }
  return jsonEncode({
    'kind': 'user_selected_attachments',
    'untrusted': true,
    'documents': documents,
  });
}

bool _isTextFile(String value) {
  const extensions = {
    '.c',
    '.cpp',
    '.cs',
    '.css',
    '.csv',
    '.dart',
    '.go',
    '.html',
    '.ini',
    '.java',
    '.js',
    '.json',
    '.jsx',
    '.kt',
    '.log',
    '.md',
    '.php',
    '.properties',
    '.py',
    '.rb',
    '.rs',
    '.sql',
    '.toml',
    '.ts',
    '.tsx',
    '.txt',
    '.xml',
    '.yaml',
    '.yml',
  };
  return extensions.contains(path.extension(value).toLowerCase());
}
