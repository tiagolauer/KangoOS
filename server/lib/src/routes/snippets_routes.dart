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
        return Response(502,
            body: jsonEncode({'error': 'semantic search failed: $e'}), headers: jsonHeaders);
      }
    } else {
      snippets = await database.searchByKeyword(query);
    }
    return Response.ok(
      jsonEncode(snippets.map((s) => s.toJson()).toList()),
      headers: jsonHeaders,
    );
  });

  router.post('/', (Request request) async {
    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final title = (body['title'] as String?)?.trim() ?? '';
    final content = body['content'] as String? ?? '';
    if (title.isEmpty || content.isEmpty) {
      return Response(400,
          body: jsonEncode({'error': 'title and content are required'}), headers: jsonHeaders);
    }
    final language = (body['language'] as String?)?.trim();
    final tags = (body['tags'] as List?)?.cast<String>() ?? const <String>[];

    final id = await database.createSnippet(SnippetsCompanion.insert(
      title: title,
      content: content,
      language: Value(language == null || language.isEmpty ? null : language),
      tags: Value(tags),
    ));
    final created = await database.getSnippetById(id);
    return Response.ok(jsonEncode(created!.toJson()), headers: jsonHeaders);
  });

  router.get('/<id>', (Request request, String id) async {
    final snippet = await database.getSnippetById(int.parse(id));
    if (snippet == null) {
      return Response.notFound(jsonEncode({'error': 'not found'}), headers: jsonHeaders);
    }
    return Response.ok(jsonEncode(snippet.toJson()), headers: jsonHeaders);
  });

  router.put('/<id>', (Request request, String id) async {
    final existing = await database.getSnippetById(int.parse(id));
    if (existing == null) {
      return Response.notFound(jsonEncode({'error': 'not found'}), headers: jsonHeaders);
    }

    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final title = body['title'] as String?;
    final content = body['content'] as String?;
    final tags = (body['tags'] as List?)?.cast<String>();

    final updated = existing.copyWith(
      title: title ?? existing.title,
      content: content ?? existing.content,
      language: body.containsKey('language')
          ? Value(_normalize(body['language'] as String?))
          : Value(existing.language),
      tags: tags ?? existing.tags,
      updatedAt: DateTime.now(),
    );
    await database.updateSnippet(updated);
    unawaited(semanticSearch.indexSnippet(updated).catchError((_) {}));

    return Response.ok(jsonEncode(updated.toJson()), headers: jsonHeaders);
  });

  router.delete('/<id>', (Request request, String id) async {
    await database.deleteSnippet(int.parse(id));
    return Response(204);
  });

  router.post('/<id>/index', (Request request, String id) async {
    final snippet = await database.getSnippetById(int.parse(id));
    if (snippet == null) {
      return Response.notFound(jsonEncode({'error': 'not found'}), headers: jsonHeaders);
    }
    try {
      await semanticSearch.indexSnippet(snippet);
    } catch (e) {
      return Response(502,
          body: jsonEncode({'error': 'indexing failed: $e'}), headers: jsonHeaders);
    }
    return Response.ok(jsonEncode({'status': 'indexed'}), headers: jsonHeaders);
  });

  return router;
}

String? _normalize(String? value) => value == null || value.isEmpty ? null : value;
