import 'package:drift/drift.dart';

import '../../connectors/agent_connector.dart';
import 'memory_episodes_table.dart';

enum ConnectorSourceKind { file, browser, calendar, web }

class ConnectorSourceKindConverter
    extends TypeConverter<ConnectorSourceKind, String> {
  const ConnectorSourceKindConverter();

  @override
  ConnectorSourceKind fromSql(String fromDb) =>
      ConnectorSourceKind.values.firstWhere((kind) => kind.name == fromDb);

  @override
  String toSql(ConnectorSourceKind value) => value.name;
}

class ConnectorSurfaceConverter
    extends TypeConverter<ConnectorSurface, String> {
  const ConnectorSurfaceConverter();

  @override
  ConnectorSurface fromSql(String fromDb) =>
      ConnectorSurface.values.firstWhere((surface) => surface.name == fromDb);

  @override
  String toSql(ConnectorSurface value) => value.name;
}

class ConnectorAccessConverter extends TypeConverter<ConnectorAccess, String> {
  const ConnectorAccessConverter();

  @override
  ConnectorAccess fromSql(String fromDb) =>
      ConnectorAccess.values.firstWhere((access) => access.name == fromDb);

  @override
  String toSql(ConnectorAccess value) => value.name;
}

class ConnectorSources extends Table {
  TextColumn get id => text().withLength(min: 1, max: 128)();
  TextColumn get kind => text().map(const ConnectorSourceKindConverter())();
  TextColumn get label => text().withLength(min: 1, max: 256)();
  TextColumn get location => text().withLength(min: 1, max: 4096)();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(
  name: 'connector_tool_permissions_conversation_id_idx',
  columns: {#conversationId},
)
class ConnectorToolPermissions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get surface => text().map(const ConnectorSurfaceConverter())();
  IntColumn get conversationId => integer()();
  TextColumn get toolName => text().withLength(min: 1, max: 128)();
  TextColumn get access => text().map(const ConnectorAccessConverter())();
  DateTimeColumn get grantedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {surface, conversationId, toolName, access},
  ];
}

class LocalPersonas extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get content => text().withLength(min: 1, max: 4000)();
  TextColumn get sourceSummaryIds =>
      text().map(const IntListConverter()).withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['CHECK (id = 1)'];
}
