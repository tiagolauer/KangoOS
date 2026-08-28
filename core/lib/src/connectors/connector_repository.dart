import '../database/database.dart';
import '../database/tables/agent_context_tables.dart';
import 'agent_connector.dart';

class ConnectorSourceInput {
  const ConnectorSourceInput({
    required this.id,
    required this.kind,
    required this.label,
    required this.location,
    this.enabled = true,
  });

  final String id;
  final ConnectorSourceKind kind;
  final String label;
  final String location;
  final bool enabled;
}

abstract interface class ConnectorRepository {
  Future<ConnectorSource?> source(String id);

  Future<List<ConnectorSource>> sources({bool? enabled});

  Future<ConnectorSource> upsertSource(ConnectorSourceInput source);

  Future<int> deleteSource(String id);

  Future<bool> isToolAllowed({
    required ConnectorSurface surface,
    required int? conversationId,
    required String toolName,
    required ConnectorAccess access,
  });

  Future<void> grantTool({
    required ConnectorSurface surface,
    required int conversationId,
    required String toolName,
    required ConnectorAccess access,
  });

  Future<int> revokeTool({
    required ConnectorSurface surface,
    required int conversationId,
    required String toolName,
    required ConnectorAccess access,
  });

  Future<List<ConnectorToolPermission>> permissionsForConversation(
    int conversationId,
  );

  Future<int> revokeConversationPermissions(int conversationId);
}
