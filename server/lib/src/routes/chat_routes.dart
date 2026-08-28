import 'dart:async';
import 'dart:convert';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:shelf/shelf.dart';

Handler chatHandler({required RagChat ragChat, required LlmProvider provider}) {
  return (Request request) async {
    final body = _decodeObject(await request.readAsString());
    if (body == null) return _error('body must be a JSON object');

    final message =
        body['message'] is String ? (body['message'] as String).trim() : '';
    if (message.isEmpty) return _error('message is required');

    final historyJson = body['history'] ?? const [];
    if (historyJson is! List) return _error('history must be a list');

    final history = <LlmMessage>[];
    for (final entry in historyJson) {
      if (entry is! Map<String, dynamic>) {
        return _error('each history entry must be an object');
      }
      final roles = LlmRole.values.where(
        (candidate) =>
            (candidate == LlmRole.user || candidate == LlmRole.assistant) &&
            candidate.name == entry['role'],
      );
      if (roles.isEmpty) {
        return _error('history role must be user or assistant');
      }
      final role = roles.first;
      if (entry['content'] is! String) {
        return _error('history content must be a string');
      }
      history.add(LlmMessage(role: role, content: entry['content'] as String));
    }

    final controller = StreamController<List<int>>();
    ragChat
        .reply(provider: provider, history: history, userMessage: message)
        .listen(
          (chunk) => controller.add(
            utf8.encode('data: ${jsonEncode({'text': chunk})}\n\n'),
          ),
          onDone: controller.close,
          onError: (Object error, StackTrace stackTrace) {
            controller.add(
              utf8.encode(
                'event: error\ndata: ${jsonEncode({'error': '$error'})}\n\n',
              ),
            );
            controller.close();
          },
        );

    return Response.ok(
      controller.stream,
      headers: {
        'content-type': 'text/event-stream',
        'cache-control': 'no-cache',
        'connection': 'keep-alive',
      },
    );
  };
}

Response _error(String message) => Response(
  400,
  body: jsonEncode({'error': message}),
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic>? _decodeObject(String body) {
  try {
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : null;
  } on FormatException {
    return null;
  }
}
