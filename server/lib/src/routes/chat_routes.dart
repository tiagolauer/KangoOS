import 'dart:async';
import 'dart:convert';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:shelf/shelf.dart';

Handler chatHandler({required RagChat ragChat, required LlmProvider provider}) {
  return (Request request) async {
    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final message = (body['message'] as String?)?.trim();
    if (message == null || message.isEmpty) {
      return Response(400,
          body: jsonEncode({'error': 'message is required'}),
          headers: {'content-type': 'application/json'});
    }

    final historyJson = (body['history'] as List?) ?? const [];
    final history = historyJson.map((entry) {
      final map = entry as Map<String, dynamic>;
      final role = LlmRole.values.firstWhere((r) => r.name == map['role']);
      return LlmMessage(role: role, content: map['content'] as String);
    }).toList();

    final controller = StreamController<List<int>>();
    ragChat.reply(provider: provider, history: history, userMessage: message).listen(
      (chunk) => controller.add(utf8.encode('data: ${jsonEncode({'text': chunk})}\n\n')),
      onDone: controller.close,
      onError: (Object error, StackTrace stackTrace) {
        controller.add(utf8.encode('event: error\ndata: ${jsonEncode({'error': '$error'})}\n\n'));
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
