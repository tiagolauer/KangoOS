import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:kangoos_core/kangoos_core.dart';
import 'package:test/test.dart';

void main() {
  late KangoosDatabase database;

  setUp(() => database = KangoosDatabase.memory());
  tearDown(() => database.close());

  test('create, read, update, delete a snippet', () async {
    final id = await database.createSnippet(SnippetsCompanion.insert(
      title: 'Reverse a string',
      content: 'input.split("").reversed.join()',
      language: const Value('dart'),
      tags: const Value(['string', 'algorithm']),
    ));

    final created = await database.getSnippetById(id);
    expect(created, isNotNull);
    expect(created!.title, 'Reverse a string');
    expect(created.tags, ['string', 'algorithm']);

    final updated = created.copyWith(title: 'Reverse a String (Dart)');
    expect(await database.updateSnippet(updated), isTrue);
    expect((await database.getSnippetById(id))!.title, 'Reverse a String (Dart)');

    expect(await database.searchByKeyword('reverse'), hasLength(1));
    expect(await database.searchByKeyword('nonexistent'), isEmpty);

    expect(await database.deleteSnippet(id), 1);
    expect(await database.getSnippetById(id), isNull);
  });

  test('watchAllSnippets reflects inserts in updatedAt-desc order', () async {
    await database.createSnippet(SnippetsCompanion.insert(
      title: 'First',
      content: 'a',
      updatedAt: Value(DateTime.utc(2024, 1, 1)),
    ));
    await database.createSnippet(SnippetsCompanion.insert(
      title: 'Second',
      content: 'b',
      updatedAt: Value(DateTime.utc(2024, 1, 2)),
    ));

    final rows = await database.watchAllSnippets().first;

    expect(rows.map((row) => row.title), ['Second', 'First']);
  });
}
