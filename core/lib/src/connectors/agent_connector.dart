import 'dart:async';

import '../llm/llm_provider.dart';
import '../llm/llm_stream.dart';

enum ConnectorAccess { read, write, external }

enum ConnectorSurface { desktop, mcp, server }

enum ConnectorEvidenceKind { file, browser, calendar, web, persona }

class ConnectorEvidence {
  const ConnectorEvidence({
    required this.id,
    required this.kind,
    required this.title,
    required this.content,
    this.uri,
    this.startedAt,
    this.endedAt,
  });

  final String id;
  final ConnectorEvidenceKind kind;
  final String title;
  final String content;
  final Uri? uri;
  final DateTime? startedAt;
  final DateTime? endedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'content': content,
    if (uri != null) 'uri': uri.toString(),
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
    'untrusted': true,
  };
}

class ConnectorToolResult {
  const ConnectorToolResult({required this.data, this.evidence = const []});

  final Object? data;
  final List<ConnectorEvidence> evidence;
}

class ConnectorApproval {
  const ConnectorApproval({
    required this.toolName,
    required this.access,
    required this.title,
    required this.description,
  });

  final String toolName;
  final ConnectorAccess access;
  final String title;
  final String description;
}

typedef ConnectorPermissionChecker =
    Future<bool> Function(
      String toolName,
      ConnectorAccess access,
      ConnectorSurface surface,
      int? conversationId,
    );

typedef ConnectorApprovalRequester =
    Future<bool> Function(ConnectorApproval approval);

class ConnectorRunContext {
  const ConnectorRunContext({
    required this.surface,
    required this.deadline,
    required this.permissionChecker,
    this.conversationId,
    this.cancelToken,
    this.approvalRequester,
  });

  final ConnectorSurface surface;
  final int? conversationId;
  final DateTime deadline;
  final ConnectorPermissionChecker permissionChecker;
  final CancelToken? cancelToken;
  final ConnectorApprovalRequester? approvalRequester;

  Future<void> guard(String toolName, ConnectorAccess access) async {
    if (cancelToken?.isCancelled ?? false) {
      throw const ConnectorCancelledException();
    }
    if (!DateTime.now().isBefore(deadline)) {
      throw TimeoutException('connector deadline exceeded');
    }
    if (!await permissionChecker(toolName, access, surface, conversationId)) {
      throw ConnectorPermissionException(toolName);
    }
  }
}

abstract interface class AgentConnectorTool {
  LlmToolDefinition get definition;

  ConnectorAccess get access;

  ConnectorApproval approval(Map<String, Object?> arguments);

  Future<ConnectorToolResult> execute(
    Map<String, Object?> arguments,
    ConnectorRunContext context,
  );
}

class AgentConnectorRegistry {
  AgentConnectorRegistry([Iterable<AgentConnectorTool> tools = const []])
    : _tools = {for (final tool in tools) tool.definition.name: tool} {
    if (_tools.length != tools.length) {
      throw ArgumentError('Connector tool names must be unique.');
    }
  }

  final Map<String, AgentConnectorTool> _tools;

  List<LlmToolDefinition> get definitions =>
      _tools.values.map((tool) => tool.definition).toList(growable: false);

  Future<List<LlmToolDefinition>> definitionsFor(
    ConnectorRunContext context,
  ) async {
    final allowed = <LlmToolDefinition>[];
    for (final tool in _tools.values) {
      if (await context.permissionChecker(
        tool.definition.name,
        tool.access,
        context.surface,
        context.conversationId,
      )) {
        allowed.add(tool.definition);
      }
    }
    return allowed;
  }

  bool contains(String name) => _tools.containsKey(name);

  Future<ConnectorToolResult> execute(
    String name,
    Map<String, Object?> arguments,
    ConnectorRunContext context,
  ) async {
    final tool = _tools[name];
    if (tool == null) throw ArgumentError.value(name, 'name', 'unknown tool');
    await context.guard(name, tool.access);
    if (tool.access != ConnectorAccess.read) {
      final requester = context.approvalRequester;
      if (requester == null) throw ConnectorApprovalRequiredException(name);
      if (!await requester(tool.approval(arguments))) {
        throw ConnectorApprovalDeniedException(name);
      }
      await context.guard(name, tool.access);
    }
    final result = await tool.execute(arguments, context);
    await context.guard(name, tool.access);
    return result;
  }
}

class ConnectorPermissionException implements Exception {
  const ConnectorPermissionException(this.toolName);

  final String toolName;

  @override
  String toString() => 'Permission denied for connector tool: $toolName';
}

class ConnectorApprovalRequiredException implements Exception {
  const ConnectorApprovalRequiredException(this.toolName);

  final String toolName;

  @override
  String toString() => 'Explicit approval is required for: $toolName';
}

class ConnectorApprovalDeniedException implements Exception {
  const ConnectorApprovalDeniedException(this.toolName);

  final String toolName;

  @override
  String toString() => 'Approval denied for connector tool: $toolName';
}

class ConnectorCancelledException implements Exception {
  const ConnectorCancelledException();

  @override
  String toString() => 'Connector execution cancelled';
}
