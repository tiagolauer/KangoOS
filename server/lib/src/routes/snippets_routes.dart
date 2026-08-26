import 'dart:convert';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const jsonHeaders = {'content-type': 'application/json'};

Router snippetsRouter({
  required SnippetRepository repository,
  required SnippetService snippets,
}) {
  final router = Router();

  router.get('/', (Request request) async {
    final query = request.url.queryParameters['q'];
    final mode = request.url.queryParameters['mode'] ?? 'keyword';

    List<Snippet> results;
    if (query == null || query.isEmpty) {
      results = await snippets.list();
    } else {
      try {
        results = await snippets.search(
          query,
          mode: mode == 'semantic'
              ? SnippetSearchMode.semantic
              : SnippetSearchMode.keyword,
        );
      } catch (error) {
        return _error(502, 'snippet search failed: $error');
      }
    }
    return Response.ok(
      jsonEncode(results.map(snippetToJson).toList()),
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
      await repository.clearTombstone(syncId);
    }

    final result = await snippets.create(NewSnippet(
      title: title,
      content: content,
      language: language == null || language.isEmpty ? null : language,
      tags: tags,
      syncId: syncId == null || syncId.isEmpty ? null : syncId,
      createdAt: createdAt.value,
      updatedAt: updatedAt.value,
    ));
    return Response.ok(
        jsonEncode({
          ...snippetToJson(result.snippet),
          if (result.indexingError != null)
            'indexingWarning': '${result.indexingError}',
        }),
        headers: jsonHeaders);
  });

  router.get('/deleted', (Request request) async {
    final tombstones = await repository.tombstones();
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
    final existing = await repository.getBySyncId(syncId);
    if (existing != null) {
      await snippets.delete(existing.id);
    } else {
      await repository.recordTombstone(syncId);
    }
    return Response(204);
  });

  router.get('/<id>', (Request request, String id) async {
    final snippetId = int.tryParse(id);
    if (snippetId == null) return _error(400, 'id must be an integer');

    final snippet = await snippets.get(snippetId);
    if (snippet == null) return _error(404, 'not found');
    return Response.ok(jsonEncode(snippetToJson(snippet)),
        headers: jsonHeaders);
  });

  router.put('/<id>', (Request request, String id) async {
    final snippetId = int.tryParse(id);
    if (snippetId == null) return _error(400, 'id must be an integer');

    final existing = await snippets.get(snippetId);
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

    final result = await snippets.update(
        snippetId,
        SnippetUpdate(
          title: title ?? existing.title,
          content: content ?? existing.content,
          language: body.containsKey('language')
              ? _normalize(_optionalString(body['language']))
              : existing.language,
          languageProvided: body.containsKey('language'),
          tags: tags ?? existing.tags,
          updatedAt: updatedAt.value ?? DateTime.now(),
        ));
    return Response.ok(
        jsonEncode({
          ...snippetToJson(result!.snippet),
          if (result.indexingError != null)
            'indexingWarning': '${result.indexingError}',
        }),
        headers: jsonHeaders);
  });

  router.delete('/<id>', (Request request, String id) async {
    final snippetId = int.tryParse(id);
    if (snippetId == null) return _error(400, 'id must be an integer');

    await snippets.delete(snippetId);
    return Response(204);
  });

  router.post('/<id>/index', (Request request, String id) async {
    final snippetId = int.tryParse(id);
    if (snippetId == null) return _error(400, 'id must be an integer');

    final result = await snippets.index(snippetId);
    if (result == null) return _error(404, 'not found');
    if (result.indexingError != null) {
      return _error(502, 'indexing failed: ${result.indexingError}');
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
