import 'package:kangoos_core/kangoos_core.dart';
import 'package:test/test.dart';

class _FakeEmbeddingProvider implements EmbeddingProvider {
  _FakeEmbeddingProvider(this.vectors);

  final Map<String, List<double>> vectors;

  @override
  String get id => 'fake';

  @override
  Future<List<double>> embed(String text) async {
    for (final entry in vectors.entries) {
      if (text.contains(entry.key)) return entry.value;
    }
    return [0, 0, 1];
  }
}

void main() {
  test('cosineSimilarity ranks identical vectors above orthogonal ones', () {
    expect(cosineSimilarity([1, 0, 0], [1, 0, 0]), closeTo(1, 1e-9));
    expect(cosineSimilarity([1, 0, 0], [0, 1, 0]), closeTo(0, 1e-9));
    expect(cosineSimilarity([1, 0, 0], [-1, 0, 0]), closeTo(-1, 1e-9));
  });

  test('indexSnippet stores the embedding, search ranks by similarity', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);

    final dartId = await database.createSnippet(SnippetsCompanion.insert(
      title: 'Dart string reverse',
      content: 'input.split("").reversed.join()',
    ));
    final pythonId = await database.createSnippet(SnippetsCompanion.insert(
      title: 'Python list sort',
      content: 'sorted(my_list)',
    ));

    final embeddingProvider = _FakeEmbeddingProvider({
      'Dart': [1, 0, 0],
      'Python': [0, 1, 0],
    });
    final semanticSearch = SemanticSearch(
      database: database,
      embeddingProvider: embeddingProvider,
    );

    await semanticSearch.indexSnippet((await database.getSnippetById(dartId))!);
    await semanticSearch.indexSnippet((await database.getSnippetById(pythonId))!);

    final indexed = await database.snippetsWithEmbedding();
    expect(indexed, hasLength(2));

    final results = await semanticSearch.search('Dart question');
    expect(results.first.snippet.title, 'Dart string reverse');
    expect(results.first.score, greaterThan(results.last.score));
  });

  test('indexMissing only embeds snippets without one and returns the count', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);

    await database.createSnippet(SnippetsCompanion.insert(title: 'A', content: 'a'));
    await database.createSnippet(SnippetsCompanion.insert(title: 'B', content: 'b'));

    final semanticSearch = SemanticSearch(
      database: database,
      embeddingProvider: _FakeEmbeddingProvider(const {}),
    );

    final indexedCount = await semanticSearch.indexMissing();
    expect(indexedCount, 2);
    expect(await database.snippetsMissingEmbedding(), isEmpty);

    final indexedAgainCount = await semanticSearch.indexMissing();
    expect(indexedAgainCount, 0);
  });
}
