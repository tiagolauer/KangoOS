import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/src/cli/kango_cli.dart';
import 'package:test/test.dart';

void main() {
  late KangoosDatabase database;
  late StringBuffer out;
  late StringBuffer err;

  setUp(() {
    database = KangoosDatabase.memory();
    out = StringBuffer();
    err = StringBuffer();
  });
  tearDown(() => database.close());

  Future<int> run(List<String> args, {String stdinContent = ''}) => runKangoCli(
        args,
        database: database,
        out: out,
        err: err,
        readStdin: () => stdinContent,
      );

  test('create requires a title', () async {
    final code = await run(['create'], stdinContent: 'some code');
    expect(code, 64);
    expect(err.toString(), contains('--title is required'));
  });

  test('create requires stdin content', () async {
    final code = await run(['create', '--title', 'Foo'], stdinContent: '   ');
    expect(code, 64);
    expect(err.toString(), contains('no content on stdin'));
  });

  test('create stores a snippet with language and tags from stdin', () async {
    final code = await run(
      [
        'create',
        '--title',
        'Reverse a string',
        '--language',
        'dart',
        '--tags',
        'strings, dart'
      ],
      stdinContent: 'input.split("").reversed.join()',
    );

    expect(code, 0);
    expect(out.toString(), contains('Created snippet #1'));

    final snippet = await database.getSnippetById(1);
    expect(snippet, isNotNull);
    expect(snippet!.title, 'Reverse a string');
    expect(snippet.content, 'input.split("").reversed.join()');
    expect(snippet.language, 'dart');
    expect(snippet.tags, ['strings', 'dart']);
  });

  test('list shows nothing when there are no snippets', () async {
    final code = await run(['list']);
    expect(code, 0);
    expect(out.toString(), contains('No snippets yet.'));
  });

  test('list and search show created snippets, newest first', () async {
    await run(['create', '--title', 'First'], stdinContent: 'one');
    await run(['create', '--title', 'Second'], stdinContent: 'two');

    out.clear();
    var code = await run(['list']);
    expect(code, 0);
    final lines = out.toString().trim().split('\n');
    expect(lines[0], contains('Second'));
    expect(lines[1], contains('First'));

    out.clear();
    code = await run(['search', 'First']);
    expect(code, 0);
    expect(out.toString(), contains('First'));
    expect(out.toString(), isNot(contains('Second')));
  });

  test('search without a query is a usage error', () async {
    final code = await run(['search']);
    expect(code, 64);
    expect(err.toString(), contains('requires a query'));
  });

  test('show prints the full snippet', () async {
    await run(['create', '--title', 'Foo', '--language', 'dart'],
        stdinContent: 'body text');

    out.clear();
    final code = await run(['show', '1']);

    expect(code, 0);
    expect(out.toString(), contains('Foo'));
    expect(out.toString(), contains('dart'));
    expect(out.toString(), contains('body text'));
  });

  test('show reports not found for a missing id', () async {
    final code = await run(['show', '999']);
    expect(code, 1);
    expect(err.toString(), contains('not found'));
  });

  test('edit updates only the given fields', () async {
    await run(['create', '--title', 'Foo', '--language', 'dart'],
        stdinContent: 'original');

    final code = await run(['edit', '1', '--title', 'Bar']);
    expect(code, 0);

    final snippet = await database.getSnippetById(1);
    expect(snippet!.title, 'Bar');
    expect(snippet.content, 'original');
    expect(snippet.language, 'dart');
  });

  test('delete removes a snippet', () async {
    await run(['create', '--title', 'Foo'], stdinContent: 'body');

    final code = await run(['delete', '1']);
    expect(code, 0);
    expect(await database.getSnippetById(1), isNull);
  });

  test('delete reports not found for a missing id', () async {
    final code = await run(['delete', '999']);
    expect(code, 1);
    expect(err.toString(), contains('not found'));
  });

  test('unknown command is a usage error', () async {
    final code = await run(['bogus']);
    expect(code, 64);
    expect(err.toString(), contains('Unknown command'));
  });

  test('no arguments prints usage to stderr', () async {
    final code = await run([]);
    expect(code, 64);
    expect(err.toString(), contains('Usage: kango'));
  });
}
