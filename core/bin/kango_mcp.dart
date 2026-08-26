import 'dart:convert';
import 'dart:io';

import 'package:kangoos_core/kangoos_core_storage.dart';

Future<void> main() async {
  final application = await KangoMcpApplication.open(Platform.environment);

  final lines = stdin.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.trim().isEmpty) continue;

    final Map<String, dynamic> message;
    try {
      message = jsonDecode(line) as Map<String, dynamic>;
    } catch (e) {
      stdout.writeln(jsonEncode({
        'jsonrpc': '2.0',
        'id': null,
        'error': {'code': -32700, 'message': 'Parse error: $e'},
      }));
      continue;
    }

    final response = await application.server.handleMessage(message);
    if (response != null) {
      stdout.writeln(jsonEncode(response));
    }
  }

  await application.close();
}
