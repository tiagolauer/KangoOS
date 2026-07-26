import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../chat/temporal_query.dart';
import '../database/database.dart';
import '../database/snippet_json.dart';
import '../database/tables/activity_summaries_table.dart';
import '../search/semantic_search.dart';

typedef _ToolHandler = FutureOr<Map<String, dynamic>> Function(
    Map<String, dynamic> arguments);

class _McpTool {
  const _McpTool(
      {required this.description,
      required this.inputSchema,
      required this.handler});

  final String description;
  final Map<String, dynamic> inputSchema;
  final _ToolHandler handler;
}

/// Hand-rolled MCP (Model Context Protocol) server, so IDE assistants
/// (Cursor, GitHub Copilot, Claude Desktop, etc) can search/create/edit
/// saved snippets as tools.
///
/// This project pins Dart SDK ^3.6.1, and the official `package:dart_mcp`
/// (labs.dart.dev) requires >=3.7.0 — bumping the SDK constraint here would
/// break `dart pub get` on this exact toolchain, so this hand-rolls the
/// stdio JSON-RPC 2.0 transport instead (deliberately minimal: tools only,
/// no resources/prompts/sampling). Swap in `package:dart_mcp` once the SDK
/// floor moves to 3.7+ — [handleMessage] is decoupled from stdio, so only
/// the `bin/kango_mcp.dart` entrypoint would need to change.
class KangoMcpServer {
  KangoMcpServer({
    required this.database,
    this.semanticSearch,
    this.maxLtmActivities = 100,
  }) {
    _registerTools();
  }

  final KangoosDatabase database;
  final SemanticSearch? semanticSearch;
  final int maxLtmActivities;
  final _tools = <String, _McpTool>{};

  void _registerTools() {
    _tools['search_snippets'] = _McpTool(
      description:
          'Search saved code snippets by keyword or semantic similarity.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string', 'description': 'Text to search for'},
          'semantic': {
            'type': 'boolean',
            'description':
                'Use semantic (embedding) search instead of keyword matching',
          },
          'limit': {
            'type': 'integer',
            'description': 'Max results (default 10)'
          },
        },
        'required': ['query'],
      },
      handler: _searchSnippets,
    );

    _tools['create_snippet'] = _McpTool(
      description: 'Save a new code snippet.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'content': {'type': 'string'},
          'language': {'type': 'string', 'description': 'e.g. dart, python'},
          'tags': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
        'required': ['title', 'content'],
      },
      handler: _createSnippet,
    );

    _tools['list_snippets'] = _McpTool(
      description: 'List the most recently updated snippets.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'limit': {
            'type': 'integer',
            'description': 'Max results (default 20)'
          },
        },
      },
      handler: _listSnippets,
    );

    _tools['get_snippet'] = _McpTool(
      description: 'Get a single snippet by id, including its full content.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'integer'},
        },
        'required': ['id'],
      },
      handler: _getSnippet,
    );

    _tools['update_snippet'] = _McpTool(
      description:
          "Update a snippet's fields. Only fields provided are changed.",
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'integer'},
          'title': {'type': 'string'},
          'content': {'type': 'string'},
          'language': {'type': 'string'},
          'tags': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
        'required': ['id'],
      },
      handler: _updateSnippet,
    );

    _tools['delete_snippet'] = _McpTool(
      description: 'Delete a snippet by id.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'integer'},
        },
        'required': ['id'],
      },
      handler: _deleteSnippet,
    );

    _tools['ask_kango_ltm'] = _McpTool(
      description:
          "Query KangoOS's long-term memory: captured window/app activity "
          'and recap summaries. The query can reference a time range in '
          'plain English (today, yesterday, this week, last week); it '
          'defaults to today when none is mentioned. Pass keywords to '
          'full-text-search the activity (app name, window title, captured '
          'text/url/clipboard) within that range instead of listing it '
          'chronologically.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description': 'e.g. "what did I work on yesterday?"',
          },
          'keywords': {
            'type': 'string',
            'description':
                'Optional full-text search terms, e.g. "drift migration".',
          },
        },
        'required': ['query'],
      },
      handler: _askLtm,
    );

    _tools['create_kango_memory'] = _McpTool(
      description: 'Explicitly save a durable memory, independent of activity '
          'capture. Shows up in the Timeline and is retrievable by '
          'ask_kango_ltm and chat.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'content': {'type': 'string'},
        },
        'required': ['content'],
      },
      handler: _createMemory,
    );
  }

  /// Handles one already-decoded JSON-RPC message. Returns the response
  /// object to send back, or null for notifications/no-reply messages.
  Future<Map<String, dynamic>?> handleMessage(
      Map<String, dynamic> message) async {
    final method = message['method'] as String?;
    final id = message['id'];

    try {
      switch (method) {
        case 'initialize':
          return _result(id,
              _initializeResult(message['params'] as Map<String, dynamic>?));
        case 'notifications/initialized':
          return null;
        case 'tools/list':
          return _result(id, {'tools': _toolList()});
        case 'tools/call':
          return _result(
              id, await _callTool(message['params'] as Map<String, dynamic>?));
        default:
          if (id == null) return null;
          return _error(id, -32601, 'Method not found: $method');
      }
    } catch (e) {
      if (id == null) return null;
      return _error(id, -32603, 'Internal error: $e');
    }
  }

  Map<String, dynamic> _initializeResult(Map<String, dynamic>? params) {
    return {
      'protocolVersion': params?['protocolVersion'] as String? ?? '2024-11-05',
      'capabilities': {'tools': {}},
      'serverInfo': {'name': 'kangoos', 'version': '0.1.0'},
    };
  }

  List<Map<String, dynamic>> _toolList() => _tools.entries
      .map((entry) => {
            'name': entry.key,
            'description': entry.value.description,
            'inputSchema': entry.value.inputSchema,
          })
      .toList();

  Future<Map<String, dynamic>> _callTool(Map<String, dynamic>? params) async {
    final name = params?['name'] as String?;
    final tool = _tools[name];
    if (tool == null) {
      return _toolError('Unknown tool: $name');
    }
    final arguments =
        (params?['arguments'] as Map?)?.cast<String, dynamic>() ?? const {};
    try {
      return await tool.handler(arguments);
    } catch (e) {
      return _toolError('$name failed: $e');
    }
  }

  Future<Map<String, dynamic>> _searchSnippets(
      Map<String, dynamic> args) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) return _toolError('query is required');
    final limit = (args['limit'] as num?)?.toInt() ?? 10;

    List<Snippet> results;
    if (args['semantic'] == true) {
      final search = semanticSearch;
      if (search == null) return _toolError('semantic search is not available');
      try {
        results = (await search.search(query, limit: limit))
            .map((m) => m.snippet)
            .toList();
      } catch (e) {
        return _toolError('semantic search failed: $e');
      }
    } else {
      results = (await database.searchByKeyword(query)).take(limit).toList();
    }
    return _toolJson(results.map(snippetToJson).toList());
  }

  Future<Map<String, dynamic>> _createSnippet(Map<String, dynamic> args) async {
    final title = (args['title'] as String?)?.trim() ?? '';
    final content = args['content'] as String? ?? '';
    if (title.isEmpty || content.isEmpty) {
      return _toolError('title and content are required');
    }

    final language = (args['language'] as String?)?.trim();
    final tags = (args['tags'] as List?)?.cast<String>() ?? const <String>[];

    final entry = SnippetsCompanion.insert(
      title: title,
      content: content,
      language: Value(language == null || language.isEmpty ? null : language),
      tags: Value(tags),
    );
    final search = semanticSearch;
    final id = search == null
        ? await database.createSnippet(entry)
        : await search.createAndIndex(entry);
    final created = await database.getSnippetById(id);
    return _toolJson(snippetToJson(created!));
  }

  Future<Map<String, dynamic>> _listSnippets(Map<String, dynamic> args) async {
    final limit = (args['limit'] as num?)?.toInt() ?? 20;
    final snippets = (await database.watchAllSnippets().first).take(limit);
    return _toolJson(snippets.map(snippetToJson).toList());
  }

  Future<Map<String, dynamic>> _getSnippet(Map<String, dynamic> args) async {
    final id = (args['id'] as num?)?.toInt();
    if (id == null) return _toolError('id is required');

    final snippet = await database.getSnippetById(id);
    if (snippet == null) return _toolError('snippet #$id not found');
    return _toolJson(snippetToJson(snippet));
  }

  Future<Map<String, dynamic>> _updateSnippet(Map<String, dynamic> args) async {
    final id = (args['id'] as num?)?.toInt();
    if (id == null) return _toolError('id is required');

    final existing = await database.getSnippetById(id);
    if (existing == null) return _toolError('snippet #$id not found');

    final updated = existing.copyWith(
      title: args['title'] as String? ?? existing.title,
      content: args['content'] as String? ?? existing.content,
      language: args.containsKey('language')
          ? Value(_normalize(args['language'] as String?))
          : Value(existing.language),
      tags: (args['tags'] as List?)?.cast<String>() ?? existing.tags,
      updatedAt: DateTime.now(),
    );
    await database.updateSnippet(updated);
    return _toolJson(snippetToJson(updated));
  }

  Future<Map<String, dynamic>> _deleteSnippet(Map<String, dynamic> args) async {
    final id = (args['id'] as num?)?.toInt();
    if (id == null) return _toolError('id is required');

    final deleted = await database.deleteSnippet(id);
    if (deleted == 0) return _toolError('snippet #$id not found');
    return _toolText('Deleted snippet #$id.');
  }

  Future<Map<String, dynamic>> _askLtm(Map<String, dynamic> args) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) return _toolError('query is required');

    final range = parseTemporalRange(query);
    final queryEnd = range.end.add(const Duration(seconds: 1));
    final keywords = (args['keywords'] as String?)?.trim() ?? '';
    final activities = keywords.isEmpty
        ? (await database.activitiesBetween(range.start, queryEnd))
            .take(maxLtmActivities)
            .toList()
        : await database.searchActivities(keywords,
            start: range.start, end: queryEnd, limit: maxLtmActivities);
    final summaries = await database.summariesBetween(range.start, queryEnd);

    return _toolJson({
      'rangeStart': range.start.toIso8601String(),
      'rangeEnd': range.end.toIso8601String(),
      'activities': activities.map((a) => a.toJson()).toList(),
      'summaries': summaries.map(_summaryJson).toList(),
    });
  }

  Future<Map<String, dynamic>> _createMemory(Map<String, dynamic> args) async {
    final content = (args['content'] as String?)?.trim() ?? '';
    if (content.isEmpty) return _toolError('content is required');

    final now = DateTime.now();
    final id =
        await database.insertActivitySummary(ActivitySummariesCompanion.insert(
      kind: SummaryKind.manual,
      periodStart: now,
      periodEnd: now,
      content: content,
      createdAt: Value(now),
    ));
    final created = await database.getSummaryById(id);
    return _toolJson(_summaryJson(created!));
  }

  Map<String, dynamic> _summaryJson(ActivitySummary summary) =>
      {...summary.toJson(), 'kind': summary.kind.name};

  String? _normalize(String? value) =>
      value == null || value.isEmpty ? null : value;
}

Map<String, dynamic> _toolText(String text) => {
      'content': [
        {'type': 'text', 'text': text}
      ],
    };

Map<String, dynamic> _toolJson(Object data) => _toolText(jsonEncode(data));

Map<String, dynamic> _toolError(String message) => {
      'content': [
        {'type': 'text', 'text': message}
      ],
      'isError': true,
    };

Map<String, dynamic> _result(dynamic id, Map<String, dynamic> result) =>
    {'jsonrpc': '2.0', 'id': id, 'result': result};

Map<String, dynamic> _error(dynamic id, int code, String message) => {
      'jsonrpc': '2.0',
      'id': id,
      'error': {'code': code, 'message': message}
    };
