import '../database/database.dart';
import '../search/semantic_search.dart';
import 'snippet_repository.dart';

enum SnippetSearchMode { keyword, semantic }

class SnippetMutationResult {
  const SnippetMutationResult({required this.snippet, this.indexingError});

  final Snippet snippet;
  final Object? indexingError;

  bool get indexed => indexingError == null;
}

class SnippetService {
  const SnippetService({
    required this.repository,
    this.semanticSearch,
  });

  final SnippetRepository repository;
  final SemanticSearch? semanticSearch;

  Future<SnippetMutationResult> create(NewSnippet input) async {
    final id = await repository.create(input);
    final snippet = await repository.getById(id);
    if (snippet == null) {
      throw StateError('Created snippet #$id could not be loaded.');
    }
    return _index(snippet);
  }

  Future<SnippetMutationResult?> update(
    int id,
    SnippetUpdate changes,
  ) async {
    final snippet = await repository.update(id, changes);
    if (snippet == null) return null;
    return _index(snippet);
  }

  Future<SnippetMutationResult> _index(Snippet snippet) async {
    final search = semanticSearch;
    if (search == null) return SnippetMutationResult(snippet: snippet);
    try {
      await search.indexSnippet(snippet);
      return SnippetMutationResult(
        snippet: (await repository.getById(snippet.id)) ?? snippet,
      );
    } catch (error) {
      return SnippetMutationResult(snippet: snippet, indexingError: error);
    }
  }

  Future<SnippetIndexingReport> indexPending() async {
    final search = semanticSearch;
    if (search == null) {
      return const SnippetIndexingReport(indexed: 0, failures: {});
    }
    return search.indexPending();
  }

  Future<SnippetMutationResult?> index(int id) async {
    final snippet = await repository.getById(id);
    return snippet == null ? null : _index(snippet);
  }

  Future<List<Snippet>> search(
    String query, {
    SnippetSearchMode mode = SnippetSearchMode.keyword,
    int limit = 10,
  }) async {
    if (mode == SnippetSearchMode.keyword) {
      return (await repository.searchByKeyword(query)).take(limit).toList();
    }
    final search = semanticSearch;
    if (search == null) {
      throw StateError('Semantic search is not available.');
    }
    return (await search.search(query, limit: limit))
        .map((match) => match.snippet)
        .toList();
  }

  Stream<List<Snippet>> watchAll() => repository.watchAll();

  Future<List<Snippet>> list({int? limit}) async {
    final snippets = await repository.all();
    snippets.sort((a, b) {
      final updated = b.updatedAt.compareTo(a.updatedAt);
      return updated != 0 ? updated : b.id.compareTo(a.id);
    });
    return limit == null ? snippets : snippets.take(limit).toList();
  }

  Future<Snippet?> get(int id) => repository.getById(id);

  Future<int> delete(int id) => repository.delete(id);
}
