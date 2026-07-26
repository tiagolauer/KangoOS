import 'package:drift/drift.dart';

@TableIndex(name: 'deleted_snippets_deleted_at_idx', columns: {#deletedAt})
class DeletedSnippets extends Table {
  TextColumn get syncId => text()();
  DateTimeColumn get deletedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {syncId};
}
