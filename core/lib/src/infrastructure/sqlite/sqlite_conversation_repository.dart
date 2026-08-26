import '../../chat/conversation_repository.dart';
import '../../database/database.dart';
import '../../database/tables/conversations_table.dart';
import '../../llm/llm_provider.dart';

class SqliteConversationRepository implements ConversationRepository {
  const SqliteConversationRepository(this.database);

  final KangoosDatabase database;

  @override
  Future<int> create() => database.createConversation();

  @override
  Future<int?> latestId() => database.latestConversationId();

  @override
  Future<int> appendMessage(int conversationId, LlmRole role, String content) =>
      database.appendMessage(conversationId, role, content);

  @override
  Future<int> deleteMessage(int id) => database.deleteMessage(id);

  @override
  Future<List<ConversationMessage>> messages(int conversationId) =>
      database.messagesForConversation(conversationId);

  @override
  Future<List<ConversationMessage>> search(
    String query, {
    DateTime? start,
    DateTime? end,
    int limit = 20,
  }) => database.searchConversationMessages(
    query,
    start: start,
    end: end,
    limit: limit,
  );

  @override
  Future<List<ConversationMessage>> between(
    DateTime start,
    DateTime end, {
    int? limit,
  }) => database.conversationMessagesBetween(start, end, limit: limit);

  @override
  Future<List<ConversationMessage>> byIds(List<int> ids) =>
      database.conversationMessagesByIds(ids);

  @override
  Future<List<ConversationMessage>> pendingEmbedding(
    String providerId, {
    int? limit,
  }) => database.conversationMessagesPendingEmbedding(providerId, limit: limit);

  @override
  Future<List<ConversationMessageVector>> vectors(String providerId) =>
      database.conversationMessageVectors(providerId);

  @override
  Future<void> setEmbedding(
    int id,
    List<double> embedding,
    String providerId,
  ) => database.setConversationMessageEmbedding(id, embedding, providerId);

  @override
  Stream<List<ConversationSummary>> watchSummaries() =>
      database.watchConversationSummaries();

  @override
  Future<void> delete(int conversationId) =>
      database.deleteConversation(conversationId);
}
