import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../llm/llm_provider.dart';
import 'agent_connector.dart';

const maxLocalFileBytes = 1024 * 1024;
const maxLocalFileSearchResults = 20;
const localFileRevalidationInterval = 32;
const maxLocalFileSearchExcerptLength = 2000;

class LocalFileRoot {
  const LocalFileRoot({required this.id, required this.path});

  final String id;
  final String path;
}

typedef LocalFileRootsProvider = Future<List<LocalFileRoot>> Function();

class LocalFileConnector {
  LocalFileConnector({
    required this.rootsProvider,
    this.maxFileBytes = maxLocalFileBytes,
  }) {
    if (maxFileBytes < 1 || maxFileBytes > maxLocalFileBytes) {
      throw RangeError.range(
        maxFileBytes,
        1,
        maxLocalFileBytes,
        'maxFileBytes',
      );
    }
    tools = [_SearchLocalFilesTool(this), _ReadLocalFileTool(this)];
  }

  final LocalFileRootsProvider rootsProvider;
  final int maxFileBytes;
  late final List<AgentConnectorTool> tools;

  Future<ConnectorToolResult> search(
    Map<String, Object?> arguments,
    ConnectorRunContext context,
  ) async {
    final query = _requiredString(arguments, 'query');
    final normalizedQuery = query.toLowerCase();
    final limit = _limit(arguments['limit']);
    final requestedRootIds = _strings(arguments['rootIds']);
    var allowedRoots = await _loadRoots();
    final roots =
        requestedRootIds.isEmpty
            ? allowedRoots.values.toList()
            : requestedRootIds.map((id) {
              final root = allowedRoots[id];
              if (root == null) {
                throw LocalFileAccessException('Root not allowed: $id');
              }
              return root;
            }).toList();
    final matches = <_LocalFileMatch>[];
    var skippedBinary = 0;
    var skippedLarge = 0;
    var visited = 0;

    for (final root in roots) {
      try {
        await for (final entity in Directory(
          root.canonicalPath,
        ).list(recursive: true, followLinks: false)) {
          if (visited++ % localFileRevalidationInterval == 0) {
            await context.guard(searchLocalFilesToolName, ConnectorAccess.read);
            allowedRoots = await _loadRoots();
            if (!_sameRoot(allowedRoots[root.source.id], root)) break;
          }
          if (await FileSystemEntity.type(entity.path, followLinks: false) !=
              FileSystemEntityType.file) {
            continue;
          }
          final file = await _validatedFile(root, entity.path);
          final relativePath = p.relative(file.path, from: root.canonicalPath);
          String content;
          try {
            content = await _readText(file);
          } on LocalFileTooLargeException {
            skippedLarge++;
            continue;
          } on LocalFileBinaryException {
            skippedBinary++;
            continue;
          }
          final nameMatches = p
              .basename(relativePath)
              .toLowerCase()
              .contains(normalizedQuery);
          final contentIndex = content.toLowerCase().indexOf(normalizedQuery);
          if (!nameMatches && contentIndex < 0) continue;
          matches.add(
            await _match(
              root,
              file,
              relativePath,
              _excerpt(content, contentIndex),
            ),
          );
          if (matches.length >= limit) break;
        }
      } on FileSystemException catch (error) {
        throw LocalFileAccessException(
          'Could not search root ${root.source.id}: ${error.message}',
        );
      }
      if (matches.length >= limit) break;
    }

    await context.guard(searchLocalFilesToolName, ConnectorAccess.read);
    allowedRoots = await _loadRoots();
    final visible = matches
        .where((match) => _sameRoot(allowedRoots[match.rootId], match.root))
        .take(limit)
        .toList(growable: false);
    return ConnectorToolResult(
      data: {
        'matches': visible.map((match) => match.toJson()).toList(),
        'skippedBinary': skippedBinary,
        'skippedLarge': skippedLarge,
      },
      evidence: visible.map((match) => match.evidence).toList(growable: false),
    );
  }

  Future<ConnectorToolResult> read(
    Map<String, Object?> arguments,
    ConnectorRunContext context,
  ) async {
    final rootId = _requiredString(arguments, 'rootId');
    final relativePath = _requiredString(arguments, 'path');
    final roots = await _loadRoots();
    final root = roots[rootId];
    if (root == null) {
      throw LocalFileAccessException('Root not allowed: $rootId');
    }
    final requestedPath = _resolveRelativePath(root, relativePath);
    final file = await _validatedFile(root, requestedPath);
    await context.guard(readLocalFileToolName, ConnectorAccess.read);
    final content = await _readText(file);
    final match = await _match(
      root,
      file,
      p.relative(file.path, from: root.canonicalPath),
      content,
    );
    await context.guard(readLocalFileToolName, ConnectorAccess.read);
    final currentRoot = (await _loadRoots())[rootId];
    if (!_sameRoot(currentRoot, root)) {
      throw LocalFileAccessException('Root was revoked during read: $rootId');
    }
    return ConnectorToolResult(
      data: match.toJson(),
      evidence: [match.evidence],
    );
  }

  Future<Map<String, _AllowedRoot>> _loadRoots() async {
    final allowed = <String, _AllowedRoot>{};
    for (final root in await rootsProvider()) {
      final id = root.id.trim();
      if (id.isEmpty) {
        throw const FormatException('File root id cannot be empty');
      }
      if (allowed.containsKey(id)) {
        throw FormatException('Duplicate file root id: $id');
      }
      final type = await FileSystemEntity.type(root.path, followLinks: false);
      if (type != FileSystemEntityType.directory) continue;
      final canonical = await Directory(root.path).resolveSymbolicLinks();
      allowed[id] = _AllowedRoot(
        source: LocalFileRoot(id: id, path: root.path),
        canonicalPath: p.normalize(p.absolute(canonical)),
      );
    }
    return allowed;
  }

  String _resolveRelativePath(_AllowedRoot root, String relativePath) {
    if (p.isAbsolute(relativePath) ||
        p.windows.isAbsolute(relativePath) ||
        p.posix.isAbsolute(relativePath)) {
      throw const LocalFileAccessException('Absolute paths are not allowed');
    }
    final segments = relativePath.replaceAll('\\', '/').split('/');
    if (segments.any((segment) => segment == '..')) {
      throw const LocalFileAccessException('Parent traversal is not allowed');
    }
    if (Platform.isWindows &&
        segments.any((segment) => segment.contains(':'))) {
      throw const LocalFileAccessException(
        'NTFS alternate streams are not allowed',
      );
    }
    final candidate = p.normalize(p.join(root.canonicalPath, relativePath));
    if (!_isWithin(root.canonicalPath, candidate)) {
      throw const LocalFileAccessException('Path is outside the allowed root');
    }
    return candidate;
  }

  Future<File> _validatedFile(_AllowedRoot root, String candidate) async {
    if (!_isWithin(root.canonicalPath, candidate)) {
      throw const LocalFileAccessException('Path is outside the allowed root');
    }
    if (await FileSystemEntity.type(candidate, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const LocalFileAccessException('Only regular files can be read');
    }
    final canonical = p.normalize(
      p.absolute(await File(candidate).resolveSymbolicLinks()),
    );
    if (!_isWithin(root.canonicalPath, canonical)) {
      throw const LocalFileAccessException('Symbolic links are not allowed');
    }
    return File(canonical);
  }

  Future<String> _readText(File file) async {
    final length = await file.length();
    if (length > maxFileBytes) {
      throw LocalFileTooLargeException(length, maxFileBytes);
    }
    // ponytail: bounded revalidation closes ordinary races; use native openat/
    // reparse-point handles if hostile local filesystem races become a threat.
    final bytes = await file.readAsBytes();
    if (bytes.length > maxFileBytes) {
      throw LocalFileTooLargeException(bytes.length, maxFileBytes);
    }
    if (_hasBinaryControlBytes(bytes)) {
      throw const LocalFileBinaryException();
    }
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw const LocalFileBinaryException();
    }
  }

  Future<_LocalFileMatch> _match(
    _AllowedRoot root,
    File file,
    String relativePath,
    String content,
  ) async {
    final modifiedAt = await file.lastModified();
    final normalizedRelative = p.normalize(relativePath).replaceAll('\\', '/');
    final digest = sha256.convert(utf8.encode(normalizedRelative)).toString();
    final evidence = ConnectorEvidence(
      id: 'file:${root.source.id}:${digest.substring(0, 16)}',
      kind: ConnectorEvidenceKind.file,
      title: normalizedRelative,
      content: content,
      uri: Uri.file(file.path, windows: Platform.isWindows),
      startedAt: modifiedAt,
      endedAt: modifiedAt,
    );
    return _LocalFileMatch(
      root: root,
      rootId: root.source.id,
      relativePath: normalizedRelative,
      evidence: evidence,
    );
  }

  bool _sameRoot(_AllowedRoot? current, _AllowedRoot expected) =>
      current != null &&
      _samePath(current.canonicalPath, expected.canonicalPath);

  bool _isWithin(String root, String candidate) {
    final normalizedRoot = _comparisonPath(root);
    final normalizedCandidate = _comparisonPath(candidate);
    return normalizedCandidate != normalizedRoot &&
        p.isWithin(normalizedRoot, normalizedCandidate);
  }

  String _comparisonPath(String path) {
    final normalized = p.normalize(p.absolute(path));
    return Platform.isWindows ? normalized.toLowerCase() : normalized;
  }

  bool _samePath(String left, String right) =>
      _comparisonPath(left) == _comparisonPath(right);

  String _excerpt(String content, int matchIndex) {
    if (content.length <= maxLocalFileSearchExcerptLength) return content;
    final center = matchIndex < 0 ? 0 : matchIndex;
    final start = (center - maxLocalFileSearchExcerptLength ~/ 4).clamp(
      0,
      content.length - maxLocalFileSearchExcerptLength,
    );
    return content.substring(start, start + maxLocalFileSearchExcerptLength);
  }
}

const searchLocalFilesToolName = 'search_local_files';
const readLocalFileToolName = 'read_local_file';

class _SearchLocalFilesTool implements AgentConnectorTool {
  const _SearchLocalFilesTool(this.connector);

  final LocalFileConnector connector;

  @override
  ConnectorAccess get access => ConnectorAccess.read;

  @override
  LlmToolDefinition get definition => const LlmToolDefinition(
    name: searchLocalFilesToolName,
    description:
        'Busca por nome e conteúdo somente nas pastas locais autorizadas.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string'},
        'rootIds': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 20},
      },
      'required': ['query'],
    },
  );

  @override
  ConnectorApproval approval(Map<String, Object?> arguments) =>
      const ConnectorApproval(
        toolName: searchLocalFilesToolName,
        access: ConnectorAccess.read,
        title: 'Buscar arquivos locais',
        description: 'Busca nas pastas explicitamente autorizadas.',
      );

  @override
  Future<ConnectorToolResult> execute(
    Map<String, Object?> arguments,
    ConnectorRunContext context,
  ) => connector.search(arguments, context);
}

class _ReadLocalFileTool implements AgentConnectorTool {
  const _ReadLocalFileTool(this.connector);

  final LocalFileConnector connector;

  @override
  ConnectorAccess get access => ConnectorAccess.read;

  @override
  LlmToolDefinition get definition => const LlmToolDefinition(
    name: readLocalFileToolName,
    description: 'Lê um arquivo de texto dentro de uma pasta local autorizada.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'rootId': {'type': 'string'},
        'path': {'type': 'string'},
      },
      'required': ['rootId', 'path'],
    },
  );

  @override
  ConnectorApproval approval(Map<String, Object?> arguments) =>
      ConnectorApproval(
        toolName: readLocalFileToolName,
        access: ConnectorAccess.read,
        title: 'Ler arquivo local',
        description: 'Lê ${arguments['path'] ?? 'um arquivo autorizado'}.',
      );

  @override
  Future<ConnectorToolResult> execute(
    Map<String, Object?> arguments,
    ConnectorRunContext context,
  ) => connector.read(arguments, context);
}

class LocalFileAccessException implements Exception {
  const LocalFileAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalFileTooLargeException implements Exception {
  const LocalFileTooLargeException(this.actualBytes, this.maximumBytes);

  final int actualBytes;
  final int maximumBytes;

  @override
  String toString() =>
      'File is too large: $actualBytes bytes (maximum $maximumBytes)';
}

class LocalFileBinaryException implements Exception {
  const LocalFileBinaryException();

  @override
  String toString() => 'Binary or invalid UTF-8 files are not supported';
}

class _AllowedRoot {
  const _AllowedRoot({required this.source, required this.canonicalPath});

  final LocalFileRoot source;
  final String canonicalPath;
}

class _LocalFileMatch {
  const _LocalFileMatch({
    required this.root,
    required this.rootId,
    required this.relativePath,
    required this.evidence,
  });

  final _AllowedRoot root;
  final String rootId;
  final String relativePath;
  final ConnectorEvidence evidence;

  Map<String, Object?> toJson() => {
    'rootId': rootId,
    'path': relativePath,
    ...evidence.toJson(),
  };
}

String _requiredString(Map<String, Object?> arguments, String key) {
  final value = (arguments[key] as String? ?? '').trim();
  if (value.isEmpty) throw FormatException('$key is required');
  return value;
}

List<String> _strings(Object? value) =>
    value is List
        ? value
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList()
        : const [];

int _limit(Object? value) {
  final limit = value is num ? value.toInt() : 10;
  if (limit < 1 || limit > maxLocalFileSearchResults) {
    throw RangeError.range(limit, 1, maxLocalFileSearchResults, 'limit');
  }
  return limit;
}

bool _hasBinaryControlBytes(List<int> bytes) => bytes.any(
  (byte) => byte == 0x7f || byte < 0x09 || (byte > 0x0d && byte < 0x20),
);
