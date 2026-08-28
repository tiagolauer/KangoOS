import 'package:dart_mcp/server.dart';
import 'package:kangoos_mcp/kangoos_mcp.dart';
import 'package:test/test.dart';

void main() {
  test('converts the shared tool result into the official MCP type', () {
    final result = officialToolResult({
      'content': [
        {'type': 'text', 'text': 'saved'},
      ],
      'isError': true,
    });

    expect(result.isError, isTrue);
    expect((result.content.single as TextContent).text, 'saved');
  });
}
