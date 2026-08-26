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
  Future<int> appendMessage(
    int conversationId,
    LlmRole role,
    String content,
  ) =>
      database.appendMessage(conversationId, role, content);

  @override
  Future<int> deleteMessage(int id) => database.deleteMessage(id);

  @override
  Future<List<ConversationMessage>> messages(int conversationId) =>
      database.messagesForConversation(conversationId);

  @override
  Future<List<ConversationMessage>> search(String query, {int limit = 20}) =>
      database.searchConversationMessages(query, limit: limit);

  @override
  Stream<List<ConversationSummary>> watchSummaries() =>
      database.watchConversationSummaries();

  @override
  Future<void> delete(int conversationId) =>
      database.deleteConversation(conversationId);
}
