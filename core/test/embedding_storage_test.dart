import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:kangoos_core/kangoos_core_storage.dart';
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

const _legacyActivitiesSchema = '''
CREATE TABLE activities (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  app_name TEXT NOT NULL,
  window_title TEXT NOT NULL,
  captured_text TEXT NULL,
  captured_url TEXT NULL,
  captured_clipboard TEXT NULL,
  captured_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
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
      expect(
          converter.toSql(List<double>.filled(768, 0.5)), hasLength(768 * 4));
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

    final first = await database
        .createSnippet(SnippetsCompanion.insert(title: '1', content: 'x'));
    final second = await database
        .createSnippet(SnippetsCompanion.insert(title: '2', content: 'y'));

    final ordered = await database.snippetsByIds([second, first]);

    expect(ordered.map((s) => s.id), [second, first]);
    expect(await database.snippetsByIds([]), isEmpty);
    expect(await database.snippetsByIds([first, 9999]), hasLength(1));
  });

  test('reopens an unversioned database without losing existing rows',
      () async {
    final tempDir = Directory.systemTemp.createTempSync('kangoos_unversioned');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final file = File('${tempDir.path}/partial.db');

    final initial = KangoosDatabase.native(file);
    await initial.createSnippet(
      SnippetsCompanion.insert(title: 'existing', content: 'preserved'),
    );
    await initial.close();

    final unversioned = sqlite3.open(file.path);
    unversioned.execute('PRAGMA user_version = 0;');
    unversioned.dispose();

    final reopened = KangoosDatabase.native(file);
    addTearDown(reopened.close);

    expect((await reopened.allSnippets()).single.title, 'existing');
  });

  test('repairs missing capture columns in a v17 database', () async {
    final tempDir = Directory.systemTemp.createTempSync('kangoos_v17_repair');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final file = File('${tempDir.path}/legacy.db');

    final legacy = sqlite3.open(file.path);
    legacy.execute(_legacySnippetsSchema);
    legacy.execute('''
CREATE TABLE activities (
  id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  app_name TEXT NOT NULL,
  window_title TEXT NOT NULL,
  captured_text TEXT NULL,
  captured_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
);
''');
    legacy.execute(
      'INSERT INTO snippets (title, content, embedding) VALUES (?, ?, ?);',
      [
        'existing',
        'preserved',
        jsonEncode([0.25, 0.5])
      ],
    );
    legacy.execute(
      'INSERT INTO activities (app_name, window_title) VALUES (?, ?);',
      ['code.exe', 'preserved'],
    );
    legacy.execute('''
CREATE TRIGGER activities_fts_ai AFTER INSERT ON activities BEGIN
  SELECT new.captured_url;
END;
''');
    legacy.execute('PRAGMA user_version = 17;');
    legacy.dispose();

    final repaired = KangoosDatabase.native(file);
    addTearDown(repaired.close);

    expect((await repaired.allActivities()).single.windowTitle, 'preserved');
    expect(await repaired.searchActivities('preserved'), hasLength(1));
    expect((await repaired.snippetVectors()).single.embedding, hasLength(2));
  });

  test('migrating a v11 database converts json embeddings to binary', () async {
    final tempDir = Directory.systemTemp.createTempSync('kangoos_migration');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final file = File('${tempDir.path}/legacy.db');

    final legacy = sqlite3.open(file.path);
    legacy.execute(_legacySnippetsSchema);
    legacy.execute(_legacyActivitiesSchema);
    legacy.execute(
      'INSERT INTO activities (app_name, window_title) VALUES (?, ?);',
      ['code.exe', 'legacy window'],
    );
    legacy.execute(
      'INSERT INTO snippets (title, content, embedding) VALUES (?, ?, ?);',
      [
        'legacy',
        'body',
        jsonEncode([0.25, 0.5, 0.75])
      ],
    );
    legacy.execute('INSERT INTO snippets (title, content) VALUES (?, ?);',
        ['plain', 'body']);
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

    final activities = await database.allActivities();
    expect(activities.single.windowTitle, 'legacy window');
    expect(activities.single.capturedScreenText, isNull);
    expect(await database.searchActivities('legacy'), hasLength(1));
  });

  test('migrating an old database indexes rows written before FTS existed',
      () async {
    final tempDir = Directory.systemTemp.createTempSync('kangoos_fts');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final file = File('${tempDir.path}/legacy.db');

    final legacy = sqlite3.open(file.path);
    legacy.execute(_legacySnippetsSchema);
    legacy.execute(_legacyActivitiesSchema);
    legacy.execute(
      'INSERT INTO snippets (title, content) VALUES (?, ?);',
      ['Reverse a string', 'written before the fts migration'],
    );
    legacy.execute('PRAGMA user_version = 11;');
    legacy.dispose();

    final database = KangoosDatabase.native(file);
    addTearDown(database.close);

    final found = await database.searchByKeyword('reverse');
    expect(found, hasLength(1));
    expect(found.single.title, 'Reverse a string');
  });
}
