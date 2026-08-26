import 'package:drift/drift.dart' show Value;
import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
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

class _FailingEmbeddingProvider implements EmbeddingProvider {
  @override
  String get id => 'failing';

  @override
  Future<List<double>> embed(String text) async =>
      throw StateError('ollama unreachable');
}

void main() {
  test('cosineSimilarity ranks identical vectors above orthogonal ones', () {
    expect(cosineSimilarity([1, 0, 0], [1, 0, 0]), closeTo(1, 1e-9));
    expect(cosineSimilarity([1, 0, 0], [0, 1, 0]), closeTo(0, 1e-9));
    expect(cosineSimilarity([1, 0, 0], [-1, 0, 0]), closeTo(-1, 1e-9));
  });

  test('cosineSimilarity rejects vectors of different dimensions', () {
    expect(
      () => cosineSimilarity([1, 0, 0], [1, 0, 0, 99, 99, 99]),
      throwsArgumentError,
    );
  });

  test('BruteForceVectorIndex ranks and filters compatible vectors', () {
    const index = BruteForceVectorIndex<String>();

    final matches = index.search(
      const [1, 0],
      const [
        VectorEntry(key: 'same', vector: [1, 0]),
        VectorEntry(key: 'orthogonal', vector: [0, 1]),
        VectorEntry(key: 'wrong-size', vector: [1, 0, 0]),
      ],
      limit: 2,
      minScore: 0,
    );

    expect(matches.map((match) => match.key), ['same', 'orthogonal']);
  });

  test('indexSnippet stores the embedding, search ranks by similarity',
      () async {
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
      repository: SqliteSnippetRepository(database),
      embeddingProvider: embeddingProvider,
    );

    await semanticSearch.indexSnippet((await database.getSnippetById(dartId))!);
    await semanticSearch
        .indexSnippet((await database.getSnippetById(pythonId))!);

    final indexed = await database.snippetsWithEmbedding();
    expect(indexed, hasLength(2));

    final results = await semanticSearch.search('Dart question');
    expect(results, hasLength(1));
    expect(results.first.snippet.title, 'Dart string reverse');

    final unfiltered =
        await semanticSearch.search('Dart question', minSimilarity: -1);
    expect(unfiltered, hasLength(2));
    expect(unfiltered.first.score, greaterThan(unfiltered.last.score));
  });

  test('an unrelated query returns nothing instead of the whole library',
      () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);

    final id = await database.createSnippet(SnippetsCompanion.insert(
      title: 'Bake bread',
      content: 'flour water salt yeast',
    ));

    final semanticSearch = SemanticSearch(
      repository: SqliteSnippetRepository(database),
      embeddingProvider: _FakeEmbeddingProvider({
        'Bake': [1, 0, 0],
        'kubernetes': [0, 1, 0],
      }),
    );
    await semanticSearch.indexSnippet((await database.getSnippetById(id))!);

    expect(await semanticSearch.search('kubernetes ingress tls'), isEmpty);
  });

  test('vectors from a different embedding model are skipped', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);

    await database.createSnippet(SnippetsCompanion.insert(
      title: 'Wrong dimensions',
      content: 'indexed by another model',
      embedding: const Value([1, 0, 0, 0, 0]),
      embeddingProviderId: const Value('fake'),
    ));
    final matchingId = await database.createSnippet(SnippetsCompanion.insert(
      title: 'Right dimensions',
      content: 'indexed here',
      embedding: const Value([1, 0, 0]),
      embeddingProviderId: const Value('fake'),
    ));

    final semanticSearch = SemanticSearch(
      repository: SqliteSnippetRepository(database),
      embeddingProvider: _FakeEmbeddingProvider({
        'query': [1, 0, 0],
      }),
    );

    final results = await semanticSearch.search('query');
    expect(results, hasLength(1));
    expect(results.single.snippet.id, matchingId);
  });

  test('SnippetService embeds the snippet it just created', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);

    final semanticSearch = SemanticSearch(
      repository: SqliteSnippetRepository(database),
      embeddingProvider: _FakeEmbeddingProvider({
        'Reverse': [1, 0, 0],
      }),
    );

    final result = await SnippetService(
      repository: SqliteSnippetRepository(database),
      semanticSearch: semanticSearch,
    ).create(const NewSnippet(
      title: 'Reverse a string',
      content: 'input.split("").reversed.join()',
    ));

    expect(await database.snippetsMissingEmbedding(), isEmpty);
    expect((await database.snippetVectors()).single.id, result.snippet.id);
  });

  test('SnippetService reports indexing failure and keeps the snippet',
      () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);

    final semanticSearch = SemanticSearch(
      repository: SqliteSnippetRepository(database),
      embeddingProvider: _FailingEmbeddingProvider(),
    );

    final result = await SnippetService(
      repository: SqliteSnippetRepository(database),
      semanticSearch: semanticSearch,
    ).create(const NewSnippet(title: 'Offline', content: 'no ollama here'));

    expect(result.indexingError, isA<StateError>());
    expect(
        (await database.getSnippetById(result.snippet.id))!.title, 'Offline');
    expect(await database.snippetsMissingEmbedding(), hasLength(1));
  });

  test('indexPending only embeds snippets without a current fingerprint',
      () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);

    await database
        .createSnippet(SnippetsCompanion.insert(title: 'A', content: 'a'));
    await database
        .createSnippet(SnippetsCompanion.insert(title: 'B', content: 'b'));

    final semanticSearch = SemanticSearch(
      repository: SqliteSnippetRepository(database),
      embeddingProvider: _FakeEmbeddingProvider(const {}),
    );

    final report = await semanticSearch.indexPending();
    expect(report.indexed, 2);
    expect(report.failures, isEmpty);
    expect(await database.snippetsMissingEmbedding(), isEmpty);

    final secondReport = await semanticSearch.indexPending();
    expect(secondReport.indexed, 0);
  });

  test('same-size vectors from another provider fingerprint are ignored',
      () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    await database.createSnippet(SnippetsCompanion.insert(
      title: 'Stale',
      content: 'old model',
      embedding: const Value([1, 0, 0]),
      embeddingProviderId: const Value('other-model'),
    ));
    final currentId = await database.createSnippet(SnippetsCompanion.insert(
      title: 'Current',
      content: 'current model',
      embedding: const Value([1, 0, 0]),
      embeddingProviderId: const Value('fake'),
    ));
    final search = SemanticSearch(
      repository: SqliteSnippetRepository(database),
      embeddingProvider: _FakeEmbeddingProvider({
        'query': [1, 0, 0]
      }),
    );

    final matches = await search.search('query');

    expect(matches.map((match) => match.snippet.id), [currentId]);
  });
}
