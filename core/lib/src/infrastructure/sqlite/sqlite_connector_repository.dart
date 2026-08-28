import 'package:drift/drift.dart';

import '../../connectors/agent_connector.dart';
import '../../connectors/connector_repository.dart';
import '../../database/database.dart';
import '../../memory/privacy_filter.dart';

const maxConnectorSourceIdLength = 128;
const maxConnectorSourceLabelLength = 256;
const maxConnectorSourceLocationLength = 4096;
const maxConnectorToolNameLength = 128;

class SqliteConnectorRepository implements ConnectorRepository {
  const SqliteConnectorRepository(this.database);

  final KangoosDatabase database;

  @override
  Future<ConnectorSource?> source(String id) =>
      (database.select(database.connectorSources)
        ..where((row) => row.id.equals(_sourceId(id)))).getSingleOrNull();

  @override
  Future<List<ConnectorSource>> sources({bool? enabled}) {
    final query = database.select(database.connectorSources);
    if (enabled != null) {
      query.where((row) => row.enabled.equals(enabled));
    }
    query.orderBy([
      (row) => OrderingTerm(expression: row.label.collate(Collate.noCase)),
      (row) => OrderingTerm(expression: row.id),
    ]);
    return query.get();
  }

  @override
  Future<ConnectorSource> upsertSource(ConnectorSourceInput source) async {
    final id = _sourceId(source.id);
    final label = _safeValue(
      source.label,
      'label',
      maxConnectorSourceLabelLength,
    );
    final location = _safeValue(
      source.location,
      'location',
      maxConnectorSourceLocationLength,
    );
    final existing = await this.source(id);
    final now = DateTime.now();
    await database
        .into(database.connectorSources)
        .insertOnConflictUpdate(
          ConnectorSourcesCompanion.insert(
            id: id,
            kind: source.kind,
            label: label,
            location: location,
            enabled: Value(source.enabled),
            createdAt: Value(existing?.createdAt ?? now),
            updatedAt: Value(now),
          ),
        );
    final stored = await this.source(id);
    if (stored == null) {
      throw StateError('Connector source $id could not be loaded after save.');
    }
    return stored;
  }

  @override
  Future<int> deleteSource(String id) =>
      (database.delete(database.connectorSources)
        ..where((row) => row.id.equals(_sourceId(id)))).go();

  @override
  Future<bool> isToolAllowed({
    required ConnectorSurface surface,
    required int? conversationId,
    required String toolName,
    required ConnectorAccess access,
  }) async {
    if (conversationId == null || conversationId < 1) return false;
    final normalizedToolName = _toolName(toolName);
    final grant =
        await (database.select(database.connectorToolPermissions)..where(
          (row) =>
              row.surface.equalsValue(surface) &
              row.conversationId.equals(conversationId) &
              row.toolName.equals(normalizedToolName) &
              row.access.equalsValue(access),
        )).getSingleOrNull();
    return grant != null;
  }

  @override
  Future<void> grantTool({
    required ConnectorSurface surface,
    required int conversationId,
    required String toolName,
    required ConnectorAccess access,
  }) async {
    _conversationId(conversationId);
    final conversation =
        await (database.select(database.conversations)
          ..where((row) => row.id.equals(conversationId))).getSingleOrNull();
    if (conversation == null) {
      throw StateError('Conversation $conversationId does not exist.');
    }
    await database
        .into(database.connectorToolPermissions)
        .insert(
          ConnectorToolPermissionsCompanion.insert(
            surface: surface,
            conversationId: conversationId,
            toolName: _toolName(toolName),
            access: access,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  @override
  Future<int> revokeTool({
    required ConnectorSurface surface,
    required int conversationId,
    required String toolName,
    required ConnectorAccess access,
  }) {
    _conversationId(conversationId);
    final normalizedToolName = _toolName(toolName);
    return (database.delete(database.connectorToolPermissions)..where(
      (row) =>
          row.surface.equalsValue(surface) &
          row.conversationId.equals(conversationId) &
          row.toolName.equals(normalizedToolName) &
          row.access.equalsValue(access),
    )).go();
  }

  @override
  Future<List<ConnectorToolPermission>> permissionsForConversation(
    int conversationId,
  ) {
    _conversationId(conversationId);
    final query =
        database.select(database.connectorToolPermissions)
          ..where((row) => row.conversationId.equals(conversationId))
          ..orderBy([
            (row) => OrderingTerm(expression: row.surface),
            (row) => OrderingTerm(expression: row.toolName),
            (row) => OrderingTerm(expression: row.access),
          ]);
    return query.get();
  }

  @override
  Future<int> revokeConversationPermissions(int conversationId) {
    _conversationId(conversationId);
    return (database.delete(database.connectorToolPermissions)
      ..where((row) => row.conversationId.equals(conversationId))).go();
  }

  String _sourceId(String value) =>
      _required(value, 'id', maxConnectorSourceIdLength);

  String _toolName(String value) =>
      _required(value, 'toolName', maxConnectorToolNameLength);

  String _safeValue(String value, String name, int maxLength) {
    final normalized = _required(value, name, maxLength);
    final uri = Uri.tryParse(normalized);
    if (uri?.hasScheme == true && uri!.userInfo.isNotEmpty) {
      throw ArgumentError.value(value, name, 'must not contain credentials');
    }
    if (const PrivacyFilter().filter(normalized) != normalized) {
      throw ArgumentError.value(value, name, 'must not contain credentials');
    }
    return normalized;
  }

  String _required(String value, String name, int maxLength) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > maxLength) {
      throw ArgumentError.value(
        value,
        name,
        'must contain between 1 and $maxLength characters',
      );
    }
    return normalized;
  }

  void _conversationId(int value) {
    if (value < 1) {
      throw ArgumentError.value(value, 'conversationId', 'must be positive');
    }
  }
}
