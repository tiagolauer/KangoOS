import 'package:dart_mcp/server.dart';
import 'package:kangoos_core/kangoos_core.dart';

base class KangoOfficialMcpServer extends MCPServer with ToolsSupport {
  KangoOfficialMcpServer(super.channel, this.backend)
    : super.fromStreamChannel(
        implementation: Implementation(name: 'kangoos', version: '0.1.0'),
        instructions:
            'Search local KangoOS memories and snippets before answering questions about the user or their work.',
      ) {
    for (final definition in backend.toolDefinitions) {
      registerTool(
        Tool(
          name: definition.name,
          description: definition.description,
          inputSchema: ObjectSchema.fromMap(
            definition.inputSchema.cast<String, Object?>(),
          ),
        ),
        (request) async => officialToolResult(
          await backend.callTool(
            definition.name,
            request.arguments?.cast<String, dynamic>() ?? const {},
          ),
        ),
      );
    }
  }

  final KangoMcpServer backend;
}

CallToolResult officialToolResult(Map<String, dynamic> value) {
  final content = <Content>[];
  for (final item in (value['content'] as List?) ?? const []) {
    if (item is Map && item['type'] == 'text') {
      content.add(TextContent(text: '${item['text'] ?? ''}'));
    }
  }
  return CallToolResult(content: content, isError: value['isError'] == true);
}
