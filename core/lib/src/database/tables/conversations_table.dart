import 'package:drift/drift.dart';

import '../../llm/llm_provider.dart';

class Conversations extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.preview,
    required this.messageCount,
  });

  final int id;
  final String preview;
  final int messageCount;
}

class LlmRoleConverter extends TypeConverter<LlmRole, String> {
  const LlmRoleConverter();

  @override
  LlmRole fromSql(String fromDb) =>
      LlmRole.values.firstWhere((role) => role.name == fromDb);

  @override
  String toSql(LlmRole value) => value.name;
}

@TableIndex(
    name: 'conversation_messages_conversation_id_idx',
    columns: {#conversationId})
class ConversationMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get conversationId => integer()();
  TextColumn get role => text().map(const LlmRoleConverter())();
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
