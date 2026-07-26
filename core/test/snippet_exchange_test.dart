import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:kangoos_core/kangoos_core.dart';
import 'package:test/test.dart';

void main() {
  late KangoosDatabase database;
  late SnippetExchange exchange;

  setUp(() {
    database = KangoosDatabase.memory();
    exchange = SnippetExchange(database: database);
  });
  tearDown(() => database.close());

  test('exportJson round-trips into an empty database', () async {
    await database.createSnippet(SnippetsCompanion.insert(
      title: 'Reverse a string',
      content: 'input.split("").reversed.join()',
      language: const Value('dart'),
      tags: const Value(['string', 'algorithm']),
    ));

    final json = await exchange.exportJson();

    final other = KangoosDatabase.memory();
    addTearDown(other.close);
    final result = await SnippetExchange(database: other).importJson(json);

    expect(result.imported, 1);
    expect(result.skipped, 0);
    final imported = (await other.allSnippets()).single;
    expect(imported.title, 'Reverse a string');
    expect(imported.language, 'dart');
    expect(imported.tags, ['string', 'algorithm']);
  });

  test('import skips duplicates by syncId', () async {
    await database.createSnippet(SnippetsCompanion.insert(
      title: 'A',
      content: 'body',
      syncId: const Value('sync-1'),
    ));

    final json = jsonEncode({
      'formatVersion': 1,
      'snippets': [
        {'title': 'A changed', 'content': 'different', 'syncId': 'sync-1'},
        {'title': 'B', 'content': 'new', 'syncId': 'sync-2'},
      ],
    });

    final result = await exchange.importJson(json);
    expect(result.imported, 1);
    expect(result.skipped, 1);
    expect(await database.allSnippets(), hasLength(2));
  });

  test('import skips duplicates by title+content when no syncId', () async {
    await database.createSnippet(
        SnippetsCompanion.insert(title: 'Dup', content: 'same'));

    final json = jsonEncode({
      'snippets': [
        {'title': 'Dup', 'content': 'same'},
        {'title': 'Dup', 'content': 'different'},
      ],
    });

    final result = await exchange.importJson(json);
    expect(result.imported, 1);
    expect(result.skipped, 1);
  });

  test('import skips entries missing title or content', () async {
    final json = jsonEncode({
      'snippets': [
        {'title': '', 'content': 'x'},
        {'title': 'y', 'content': ''},
        {'notasnippet': true},
        {'title': 'ok', 'content': 'valid'},
      ],
    });

    final result = await exchange.importJson(json);
    expect(result.imported, 1);
    expect(result.skipped, 3);
  });

  test('import rejects a non-KangoOS json', () async {
    expect(() => exchange.importJson('{"foo": "bar"}'),
        throwsA(isA<FormatException>()));
    expect(() => exchange.importJson('[]'),
        throwsA(isA<FormatException>()));
  });
}
