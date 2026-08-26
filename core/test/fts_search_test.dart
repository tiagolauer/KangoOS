import 'package:drift/drift.dart' show Value;
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:test/test.dart';

void main() {
  late KangoosDatabase database;

  setUp(() => database = KangoosDatabase.memory());
  tearDown(() => database.close());

  Future<int> add(String title, String content,
          {List<String> tags = const []}) =>
      database.createSnippet(SnippetsCompanion.insert(
        title: title,
        content: content,
        tags: Value(tags),
      ));

  test('matches by title, content or tags', () async {
    await add('Reverse a string', 'irrelevant body', tags: const ['algorithm']);
    await add('Unrelated', 'the string was reversed', tags: const ['other']);
    await add('Another one', 'nothing to see', tags: const ['reverse-me']);

    expect(await database.searchByKeyword('reverse'), hasLength(3));
  });

  test('multiple words require all of them (AND), in any order', () async {
    await add('Reverse a string', 'input.split');
    await add('Reverse a list', 'items.reversed');

    final results = await database.searchByKeyword('string reverse');
    expect(results, hasLength(1));
    expect(results.single.title, 'Reverse a string');
  });

  test('prefix matching finds partial words', () async {
    await add('Reverse a string', 'body');
    final results = await database.searchByKeyword('revers');
    expect(results, hasLength(1));
  });

  test('is case-insensitive', () async {
    await add('Reverse a String', 'body');
    expect(await database.searchByKeyword('REVERSE'), hasLength(1));
  });

  test('special characters in the query do not throw', () async {
    await add('C++ snippet', 'std::vector<int> v;');

    for (final query in ['C++', 'std::vector', 'a(b)', 'a"b', '-x', 'a:b*c']) {
      await expectLater(database.searchByKeyword(query), completes);
    }
  });

  test('blank query returns no results without erroring', () async {
    await add('Something', 'body');
    expect(await database.searchByKeyword('   '), isEmpty);
  });

  test('updating a snippet updates what matches', () async {
    final id = await add('Old Title', 'body');

    expect(await database.searchByKeyword('old'), hasLength(1));

    final existing = (await database.getSnippetById(id))!;
    await database.updateSnippet(existing.copyWith(title: 'New Title'));

    expect(await database.searchByKeyword('old'), isEmpty);
    expect(await database.searchByKeyword('new'), hasLength(1));
  });

  test('deleting a snippet removes it from search results', () async {
    final id = await add('Doomed', 'body');
    expect(await database.searchByKeyword('doomed'), hasLength(1));

    await database.deleteSnippet(id);

    expect(await database.searchByKeyword('doomed'), isEmpty);
  });

  test('no match returns an empty list', () async {
    await add('Something', 'body');
    expect(await database.searchByKeyword('nonexistent'), isEmpty);
  });
}
