import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:kangoos_core/kangoos_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

const _legacySnippetsSchema = '''
CREATE TABLE snippets (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  language TEXT NULL,
  tags TEXT NOT NULL DEFAULT '[]',
  embedding TEXT NULL,
  sync_id TEXT NULL,
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
  updated_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);
''';

void main() {
  group('EmbeddingConverter', () {
    test('round-trips a vector at float32 precision', () {
      const converter = EmbeddingConverter();
      final original = [0.0, 1.0, -1.0, 0.5, 0.125, 0.333333];

      final restored = converter.fromSql(converter.toSql(original));

      expect(restored, hasLength(original.length));
      for (var i = 0; i < original.length; i++) {
        expect(restored[i], closeTo(original[i], 1e-6));
      }
    });

    test('encodes four bytes per dimension', () {
      const converter = EmbeddingConverter();
      expect(converter.toSql(List<double>.filled(768, 0.5)), hasLength(768 * 4));
    });
  });

  test('snippetVectors returns what was stored', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);

    final id = await database.createSnippet(SnippetsCompanion.insert(
      title: 'a',
      content: 'b',
      embedding: Value(const [0.1, 0.2, 0.3]),
    ));
    await database.createSnippet(
        SnippetsCompanion.insert(title: 'no embedding', content: 'c'));

    final vectors = await database.snippetVectors();

    expect(vectors, hasLength(1));
    expect(vectors.single.id, id);
    expect(vectors.single.embedding[1], closeTo(0.2, 1e-6));
  });

  test('snippetsByIds preserves the requested order', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);

    final first =
        await database.createSnippet(SnippetsCompanion.insert(title: '1', content: 'x'));
    final second =
        await database.createSnippet(SnippetsCompanion.insert(title: '2', content: 'y'));

    final ordered = await database.snippetsByIds([second, first]);

    expect(ordered.map((s) => s.id), [second, first]);
    expect(await database.snippetsByIds([]), isEmpty);
    expect(await database.snippetsByIds([first, 9999]), hasLength(1));
  });

  test('migrating a v11 database converts json embeddings to binary', () async {
    final tempDir = Directory.systemTemp.createTempSync('kangoos_migration');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final file = File('${tempDir.path}/legacy.db');

    final legacy = sqlite3.open(file.path);
    legacy.execute(_legacySnippetsSchema);
    legacy.execute(
      'INSERT INTO snippets (title, content, embedding) VALUES (?, ?, ?);',
      ['legacy', 'body', jsonEncode([0.25, 0.5, 0.75])],
    );
    legacy.execute(
        'INSERT INTO snippets (title, content) VALUES (?, ?);', ['plain', 'body']);
    legacy.execute('PRAGMA user_version = 11;');
    legacy.dispose();

    final database = KangoosDatabase.native(file);
    addTearDown(database.close);

    final vectors = await database.snippetVectors();
    expect(vectors, hasLength(1));
    expect(vectors.single.embedding, hasLength(3));
    expect(vectors.single.embedding[0], closeTo(0.25, 1e-6));
    expect(vectors.single.embedding[2], closeTo(0.75, 1e-6));

    final snippets = await database.allSnippets();
    expect(snippets, hasLength(2));
    expect(snippets.map((s) => s.title), containsAll(['legacy', 'plain']));
  });
}
