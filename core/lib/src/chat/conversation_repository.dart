import '../database/database.dart';
import '../database/tables/conversations_table.dart';
import '../llm/llm_provider.dart';

abstract interface class ConversationRepository {
  Future<int> create();

  Future<int?> latestId();

  Future<int> appendMessage(int conversationId, LlmRole role, String content);

  Future<int> deleteMessage(int id);

  Future<List<ConversationMessage>> messages(int conversationId);

  Future<List<ConversationMessage>> search(
    String query, {
    DateTime? start,
    DateTime? end,
    int limit = 20,
  });

  Future<List<ConversationMessage>> between(
    DateTime start,
    DateTime end, {
    int? limit,
  });

  Future<List<ConversationMessage>> byIds(List<int> ids);

  Future<List<ConversationMessage>> pendingEmbedding(
    String providerId, {
    int? limit,
  });

  Future<List<ConversationMessageVector>> vectors(String providerId);

  Future<void> setEmbedding(int id, List<double> embedding, String providerId);

  Stream<List<ConversationSummary>> watchSummaries();

  Future<void> delete(int conversationId);
}
