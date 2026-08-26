import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:test/test.dart';

void main() {
  test('detects the language of common snippets', () {
    expect(
      detectSnippetLanguage('final reversed = input.split("").reversed;\n'
          "import 'dart:convert';"),
      'dart',
    );
    expect(
      detectSnippetLanguage('def greet(name):\n    print(name)'),
      'python',
    );
    expect(
      detectSnippetLanguage('SELECT id, title FROM snippets WHERE id = 1;'),
      'sql',
    );
    expect(detectSnippetLanguage('<div class="row">hi</div>'), 'html');
  });

  test('returns nothing for prose', () {
    expect(detectSnippetLanguage('remember to call the dentist'), isNull);
    expect(detectSnippetLanguage('   '), isNull);
  });

  test('the title is the first line, trimmed to a readable length', () {
    expect(quickCaptureTitle('\n\nfirst line\nsecond line'), 'first line');
    expect(
      quickCaptureTitle('x' * 100),
      '${'x' * maxQuickCaptureTitleLength}...',
    );
  });

  test('a quick capture records where it came from', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);

    final id = await SqliteSnippetRepository(database).create(buildQuickCapture(
      clipboard: 'SELECT 1 FROM snippets;',
      sourceApp: 'Code.exe',
    ));

    final snippet = (await database.getSnippetById(id))!;
    expect(snippet.title, 'SELECT 1 FROM snippets;');
    expect(snippet.language, 'sql');
    expect(snippet.tags, ['quick-capture', 'code.exe']);
  });
}
