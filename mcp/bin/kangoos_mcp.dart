import 'dart:io';

import 'package:dart_mcp/stdio.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:kangoos_mcp/kangoos_mcp.dart';

Future<void> main() async {
  final application = await KangoMcpApplication.open(Platform.environment);
  final server = KangoOfficialMcpServer(
    stdioChannel(input: stdin, output: stdout),
    application.server,
  );
  try {
    await server.done;
  } finally {
    await application.close();
  }
}
