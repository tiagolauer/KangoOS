import 'dart:convert';
import 'dart:io';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'auth_middleware.dart';
import 'routes/chat_routes.dart';
import 'routes/snippets_routes.dart';

class KangoosServer {
  KangoosServer({
    required this.snippetRepository,
    required this.snippets,
    required this.ragChat,
    required this.llmProvider,
    required this.apiToken,
  });

  final SnippetRepository snippetRepository;
  final SnippetService snippets;
  final RagChat ragChat;
  final LlmProvider llmProvider;
  final String apiToken;

  Handler build() {
    final router = Router()
      ..get(
        '/health',
        (Request request) =>
            Response.ok(jsonEncode({'status': 'ok'}), headers: jsonHeaders),
      )
      ..mount(
        '/snippets',
        snippetsRouter(repository: snippetRepository, snippets: snippets).call,
      )
      ..post('/index/missing', _indexMissing)
      ..post('/chat', chatHandler(ragChat: ragChat, provider: llmProvider));

    return const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(_jsonErrors())
        .addMiddleware(authMiddleware(apiToken))
        .addHandler(router.call);
  }

  Future<Response> _indexMissing(Request request) async {
    try {
      final report = await snippets.indexPending();
      return Response.ok(
        jsonEncode({
          'indexed': report.indexed,
          'failures': report.failures.map(
            (id, error) => MapEntry('$id', '$error'),
          ),
        }),
        headers: jsonHeaders,
      );
    } catch (e) {
      return Response(502,
          body: jsonEncode({'error': 'indexing failed: $e'}),
          headers: jsonHeaders);
    }
  }

  Middleware _jsonErrors() => (handler) => (request) async {
        try {
          return await handler(request);
        } catch (e, stackTrace) {
          stderr.writeln('Unhandled request error: $e\n$stackTrace');
          return Response.internalServerError(
            body: jsonEncode({'error': 'internal server error'}),
            headers: jsonHeaders,
          );
        }
      };
}
