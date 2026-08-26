import '../database/database.dart';
import '../database/tables/conversations_table.dart';
import '../llm/llm_provider.dart';

abstract interface class ConversationRepository {
  Future<int> create();

  Future<int?> latestId();

  Future<int> appendMessage(
    int conversationId,
    LlmRole role,
    String content,
  );

  Future<int> deleteMessage(int id);

  Future<List<ConversationMessage>> messages(int conversationId);

  Future<List<ConversationMessage>> search(String query, {int limit = 20});

  Stream<List<ConversationSummary>> watchSummaries();

  Future<void> delete(int conversationId);
}
