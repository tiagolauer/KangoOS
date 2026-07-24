import '../database/database.dart';
import '../llm/llm_provider.dart';
import '../search/semantic_search.dart';

class RagChat {
  RagChat({
    required this.database,
    required this.semanticSearch,
    this.maxContextSnippets = 5,
  });

  final KangoosDatabase database;
  final SemanticSearch semanticSearch;
  final int maxContextSnippets;

  Future<List<Snippet>> retrieveContext(String query) async {
    try {
      final matches = await semanticSearch.search(query, limit: maxContextSnippets);
      if (matches.isNotEmpty) return matches.map((match) => match.snippet).toList();
    } catch (_) {}
    final matches = await database.searchByKeyword(query);
    return matches.take(maxContextSnippets).toList();
  }

  String buildSystemPrompt(List<Snippet> context) {
    final buffer = StringBuffer(
      'You are the KangoOS assistant. Answer using the snippets below when '
      'relevant. If none are relevant, say so and answer generally.',
    );
    for (final snippet in context) {
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln('Title: ${snippet.title}');
      if (snippet.language != null && snippet.language!.isNotEmpty) {
        buffer.writeln('Language: ${snippet.language}');
      }
      buffer.writeln(snippet.content);
    }
    return buffer.toString();
  }

  Stream<String> reply({
    required LlmProvider provider,
    required List<LlmMessage> history,
    required String userMessage,
  }) async* {
    final context = await retrieveContext(userMessage);
    final requestMessages = [
      LlmMessage(role: LlmRole.system, content: buildSystemPrompt(context)),
      ...history,
      LlmMessage(role: LlmRole.user, content: userMessage),
    ];
    yield* provider.chat(requestMessages);
  }
}
