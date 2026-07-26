import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:kangoos_core/kangoos_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const jsonHeaders = {'content-type': 'application/json'};

Router snippetsRouter({
  required KangoosDatabase database,
  required SemanticSearch semanticSearch,
}) {
  final router = Router();

  router.get('/', (Request request) async {
    final query = request.url.queryParameters['q'];
    final mode = request.url.queryParameters['mode'] ?? 'keyword';

    List<Snippet> snippets;
    if (query == null || query.isEmpty) {
      snippets = await database.allSnippets();
    } else if (mode == 'semantic') {
      try {
        final matches = await semanticSearch.search(query);
        snippets = matches.map((match) => match.snippet).toList();
      } catch (e) {
        return _error(502, 'semantic search failed: $e');
      }
    } else {
      snippets = await database.searchByKeyword(query);
    }
    return Response.ok(
      jsonEncode(snippets.map(snippetToJson).toList()),
      headers: jsonHeaders,
    );
  });

  router.post('/', (Request request) async {
    final body = _decodeObject(await request.readAsString());
    if (body == null) return _error(400, 'body must be a JSON object');

    final title = _optionalString(body['title'])?.trim() ?? '';
    final content = _optionalString(body['content']) ?? '';
    if (title.isEmpty || content.isEmpty) {
      return _error(400, 'title and content are required');
    }

    final tags = _stringList(body['tags']);
    if (tags == null) return _error(400, 'tags must be a list of strings');

    final language = _optionalString(body['language']);
    final syncId = _optionalString(body['syncId']);
    final createdAt = _optionalMillis(body['createdAt']);
    final updatedAt = _optionalMillis(body['updatedAt']);
    if (createdAt.invalid || updatedAt.invalid) {
      return _error(400, 'createdAt and updatedAt must be epoch milliseconds');
    }

    if (syncId != null && syncId.isNotEmpty) {
      await database.clearSnippetTombstone(syncId);
    }

    final id = await semanticSearch.createAndIndex(SnippetsCompanion.insert(
      title: title,
      content: content,
      language: Value(language == null || language.isEmpty ? null : language),
      tags: Value(tags),
      syncId: Value(syncId == null || syncId.isEmpty ? null : syncId),
      createdAt: createdAt.value == null
          ? const Value.absent()
          : Value(createdAt.value!),
      updatedAt: updatedAt.value == null
          ? const Value.absent()
          : Value(updatedAt.value!),
    ));
    final created = await database.getSnippetById(id);
    return Response.ok(jsonEncode(snippetToJson(created!)),
        headers: jsonHeaders);
  });

  router.get('/deleted', (Request request) async {
    final tombstones = await database.snippetTombstones();
    return Response.ok(
      jsonEncode(tombstones
          .map((t) => {
                'syncId': t.syncId,
                'deletedAt': t.deletedAt.millisecondsSinceEpoch,
              })
          .toList()),
      headers: jsonHeaders,
    );
  });

  router.delete('/by-sync-id/<syncId>', (Request request, String syncId) async {
    final existing = await database.getSnippetBySyncId(syncId);
    if (existing != null) {
      await database.deleteSnippet(existing.id);
    } else {
      await database.recordSnippetTombstone(syncId);
    }
    return Response(204);
  });

  router.get('/<id>', (Request request, String id) async {
    final snippetId = int.tryParse(id);
    if (snippetId == null) return _error(400, 'id must be an integer');

    final snippet = await database.getSnippetById(snippetId);
    if (snippet == null) return _error(404, 'not found');
    return Response.ok(jsonEncode(snippetToJson(snippet)),
        headers: jsonHeaders);
  });

  router.put('/<id>', (Request request, String id) async {
    final snippetId = int.tryParse(id);
    if (snippetId == null) return _error(400, 'id must be an integer');

    final existing = await database.getSnippetById(snippetId);
    if (existing == null) return _error(404, 'not found');

    final body = _decodeObject(await request.readAsString());
    if (body == null) return _error(400, 'body must be a JSON object');

    final title = _optionalString(body['title']);
    final content = _optionalString(body['content']);
    final tags = body.containsKey('tags') ? _stringList(body['tags']) : null;
    if (body.containsKey('tags') && tags == null) {
      return _error(400, 'tags must be a list of strings');
    }
    final updatedAt = _optionalMillis(body['updatedAt']);
    if (updatedAt.invalid) {
      return _error(400, 'updatedAt must be epoch milliseconds');
    }

    final updated = existing.copyWith(
      title: title ?? existing.title,
      content: content ?? existing.content,
      language: body.containsKey('language')
          ? Value(_normalize(_optionalString(body['language'])))
          : Value(existing.language),
      tags: tags ?? existing.tags,
      updatedAt: updatedAt.value ?? DateTime.now(),
    );
    await database.updateSnippet(updated);
    unawaited(semanticSearch.indexSnippet(updated).catchError((Object _) {}));

    return Response.ok(jsonEncode(snippetToJson(updated)),
        headers: jsonHeaders);
  });

  router.delete('/<id>', (Request request, String id) async {
    final snippetId = int.tryParse(id);
    if (snippetId == null) return _error(400, 'id must be an integer');

    await database.deleteSnippet(snippetId);
    return Response(204);
  });

  router.post('/<id>/index', (Request request, String id) async {
    final snippetId = int.tryParse(id);
    if (snippetId == null) return _error(400, 'id must be an integer');

    final snippet = await database.getSnippetById(snippetId);
    if (snippet == null) return _error(404, 'not found');
    try {
      await semanticSearch.indexSnippet(snippet);
    } catch (e) {
      return _error(502, 'indexing failed: $e');
    }
    return Response.ok(jsonEncode({'status': 'indexed'}), headers: jsonHeaders);
  });

  return router;
}

Response _error(int status, String message) => Response(
      status,
      body: jsonEncode({'error': message}),
      headers: jsonHeaders,
    );

Map<String, dynamic>? _decodeObject(String body) {
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}

List<String>? _stringList(Object? raw) {
  if (raw == null) return const [];
  if (raw is! List || raw.any((entry) => entry is! String)) return null;
  return raw.cast<String>();
}

String? _optionalString(Object? raw) => raw is String ? raw : null;

_OptionalTimestamp _optionalMillis(Object? raw) {
  if (raw == null) return const _OptionalTimestamp(value: null);
  if (raw is! int) return const _OptionalTimestamp(value: null, invalid: true);
  return _OptionalTimestamp(value: DateTime.fromMillisecondsSinceEpoch(raw));
}

class _OptionalTimestamp {
  const _OptionalTimestamp({required this.value, this.invalid = false});

  final DateTime? value;
  final bool invalid;
}

String? _normalize(String? value) =>
    value == null || value.isEmpty ? null : value;
