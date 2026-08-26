import 'dart:async';
import 'dart:convert';

import '../chat/temporal_query.dart';
import '../connectors/agent_connector.dart';
import '../database/database.dart';
import '../database/snippet_json.dart';
import '../llm/llm_provider.dart';
import '../memory/memory_agent.dart';
import '../memory/memory_deletion.dart';
import '../memory/memory_service.dart';
import '../memory/memory_query_engine.dart';
import '../snippets/snippet_repository.dart';
import '../snippets/snippet_service.dart';

typedef _ToolHandler =
    FutureOr<Map<String, dynamic>> Function(Map<String, dynamic> arguments);

const maxMcpMemoryResults = 100;

class _McpTool {
  const _McpTool({
    required this.description,
    required this.inputSchema,
    required this.handler,
  });

  final String description;
  final Map<String, dynamic> inputSchema;
  final _ToolHandler handler;
}

class KangoMcpToolDefinition {
  const KangoMcpToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
}

class KangoMcpServer {
  KangoMcpServer({
    required this.snippets,
    required this.memory,
    this.agent,
    this.llmProvider,
    this.maxLtmActivities = 100,
  }) {
    _registerTools();
  }

  final SnippetService snippets;
  final MemoryService memory;
  final MemoryAgent? agent;
  final LlmProvider? llmProvider;
  final int maxLtmActivities;
  final _tools = <String, _McpTool>{};

  List<KangoMcpToolDefinition> get toolDefinitions => _tools.entries
      .map(
        (entry) => KangoMcpToolDefinition(
          name: entry.key,
          description: entry.value.description,
          inputSchema: entry.value.inputSchema,
        ),
      )
      .toList(growable: false);

  Future<Map<String, dynamic>> callTool(
    String name, [
    Map<String, dynamic> arguments = const {},
  ]) async {
    final tool = _tools[name];
    if (tool == null) return _toolError('Unknown tool: $name');
    try {
      return await tool.handler(arguments);
    } catch (error) {
      return _toolError('$name failed: $error');
    }
  }

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
            'description': 'Max results (default 10)',
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
            'description': 'Max results (default 20)',
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

    final memorySearchSchema = {
      'type': 'object',
      'properties': {
        'query': {'type': 'string'},
        'limit': {'type': 'integer'},
        'sources': {
          'type': 'array',
          'items': {
            'type': 'string',
            'enum':
                MemoryEvidenceSource.values.map((item) => item.name).toList(),
          },
        },
        'applications': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'modalities': {
          'type': 'array',
          'items': {
            'type': 'string',
            'enum': MemoryModality.values.map((item) => item.name).toList(),
          },
        },
        'projects': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'start': {'type': 'string', 'description': 'ISO-8601 instant'},
        'end': {'type': 'string', 'description': 'ISO-8601 instant'},
      },
      'required': ['query'],
    };
    _tools['search_memories'] = _McpTool(
      description:
          'Search episodes, summaries, durable memories, conversations and snippets with hybrid lexical, semantic and temporal retrieval.',
      inputSchema: memorySearchSchema,
      handler: _searchMemories,
    );
    _tools['search_memories_semantic'] = _McpTool(
      description: 'Search all memory sources using semantic similarity only.',
      inputSchema: memorySearchSchema,
      handler: _searchMemoriesSemantic,
    );
    _tools['search_memories_by_time'] = _McpTool(
      description:
          'List evidence from all memory sources inside a natural-language time range.',
      inputSchema: memorySearchSchema,
      handler: _searchMemoriesByTime,
    );

    _tools['get_memory_episode'] = _McpTool(
      description: 'Get one structured memory episode by id.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'integer'},
        },
        'required': ['id'],
      },
      handler: _getMemoryEpisode,
    );

    _tools['list_recent_memories'] = _McpTool(
      description: 'List recently formed memory episodes.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'limit': {'type': 'integer'},
        },
      },
      handler: _listRecentMemories,
    );

    _tools['find_related_memories'] = _McpTool(
      description: 'Find episodes related to an existing memory episode.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'integer'},
          'limit': {'type': 'integer'},
        },
        'required': ['id'],
      },
      handler: _findRelatedMemories,
    );

    _tools['investigate_memory'] = _McpTool(
      description:
          'Investigate memories across episodes, summaries, snippets and conversations, with evidence coverage and confidence.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string'},
        },
        'required': ['query'],
      },
      handler: _investigateMemory,
    );

    _tools['deep_study'] = _McpTool(
      description:
          'Produce a deep evidence report with cross-references and explicit missing evidence.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'query': {'type': 'string'},
        },
        'required': ['query'],
      },
      handler: _deepStudy,
    );

    for (final entry
        in {'search_entities': false, 'search_projects': true}.entries) {
      _tools[entry.key] = _McpTool(
        description:
            entry.value
                ? 'Search project references extracted from memory episodes.'
                : 'Search entity references extracted from memory episodes.',
        inputSchema: memorySearchSchema,
        handler: (args) => _searchEntities(args, projectsOnly: entry.value),
      );
    }

    _tools['forget_memory'] = _McpTool(
      description: 'Delete a structured memory episode by id.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'integer'},
        },
        'required': ['id'],
      },
      handler: _forgetMemory,
    );

    for (final entry
        in {'get_daily_summary': false, 'get_weekly_summary': true}.entries) {
      _tools[entry.key] = _McpTool(
        description:
            entry.value
                ? 'Get activity summaries for the calendar week containing a date.'
                : 'Get activity summaries for one date.',
        inputSchema: {
          'type': 'object',
          'properties': {
            'date': {
              'type': 'string',
              'description': 'ISO date, defaults to today',
            },
          },
        },
        handler: entry.value ? _getWeeklySummary : _getDailySummary,
      );
    }

    _tools['ask_kango_ltm'] = _McpTool(
      description:
          'Run the same read-only multi-turn memory agent used by KangoOS Chat. '
          'It searches local evidence, reflects on relevance, contradictions '
          'and gaps, and returns a PT-BR answer with citations.',
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
          'history': {
            'type': 'array',
            'description': 'Previous user and assistant messages.',
            'items': {
              'type': 'object',
              'properties': {
                'role': {
                  'type': 'string',
                  'enum': ['user', 'assistant'],
                },
                'content': {'type': 'string'},
              },
              'required': ['role', 'content'],
            },
          },
          'deepStudy': {'type': 'boolean'},
        },
        'required': ['query'],
      },
      handler: _askLtm,
    );

    _tools['create_kango_memory'] = _McpTool(
      description:
          'Explicitly save a durable memory, independent of activity '
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

    _tools['remember'] = _McpTool(
      description: 'Explicitly save a durable memory.',
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

  Future<Map<String, dynamic>?> handleMessage(
    Map<String, dynamic> message,
  ) async {
    final method = message['method'] as String?;
    final id = message['id'];

    try {
      switch (method) {
        case 'initialize':
          return _result(
            id,
            _initializeResult(message['params'] as Map<String, dynamic>?),
          );
        case 'notifications/initialized':
          return null;
        case 'tools/list':
          return _result(id, {'tools': _toolList()});
        case 'tools/call':
          return _result(
            id,
            await _callTool(message['params'] as Map<String, dynamic>?),
          );
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

  List<Map<String, dynamic>> _toolList() =>
      _tools.entries
          .map(
            (entry) => {
              'name': entry.key,
              'description': entry.value.description,
              'inputSchema': entry.value.inputSchema,
            },
          )
          .toList();

  Future<Map<String, dynamic>> _callTool(Map<String, dynamic>? params) async {
    final name = params?['name'] as String?;
    final arguments =
        (params?['arguments'] as Map?)?.cast<String, dynamic>() ?? const {};
    return callTool(name ?? '', arguments);
  }

  Future<Map<String, dynamic>> _searchSnippets(
    Map<String, dynamic> args,
  ) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) return _toolError('query is required');
    final limit = (args['limit'] as num?)?.toInt() ?? 10;

    final List<Snippet> results;
    try {
      results = await snippets.search(
        query,
        mode:
            args['semantic'] == true
                ? SnippetSearchMode.semantic
                : SnippetSearchMode.keyword,
        limit: limit,
      );
    } catch (error) {
      return _toolError('snippet search failed: $error');
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

    final result = await snippets.create(
      NewSnippet(
        title: title,
        content: content,
        language: language == null || language.isEmpty ? null : language,
        tags: tags,
      ),
    );
    return _toolJson({
      ...snippetToJson(result.snippet),
      if (result.indexingError != null)
        'indexingWarning': '${result.indexingError}',
    });
  }

  Future<Map<String, dynamic>> _listSnippets(Map<String, dynamic> args) async {
    final limit = (args['limit'] as num?)?.toInt() ?? 20;
    final results = await snippets.list(limit: limit);
    return _toolJson(results.map(snippetToJson).toList());
  }

  Future<Map<String, dynamic>> _getSnippet(Map<String, dynamic> args) async {
    final id = (args['id'] as num?)?.toInt();
    if (id == null) return _toolError('id is required');

    final snippet = await snippets.get(id);
    if (snippet == null) return _toolError('snippet #$id not found');
    return _toolJson(snippetToJson(snippet));
  }

  Future<Map<String, dynamic>> _updateSnippet(Map<String, dynamic> args) async {
    final id = (args['id'] as num?)?.toInt();
    if (id == null) return _toolError('id is required');

    final existing = await snippets.get(id);
    if (existing == null) return _toolError('snippet #$id not found');

    final result = await snippets.update(
      id,
      SnippetUpdate(
        title: args['title'] as String? ?? existing.title,
        content: args['content'] as String? ?? existing.content,
        language:
            args.containsKey('language')
                ? _normalize(args['language'] as String?)
                : existing.language,
        languageProvided: args.containsKey('language'),
        tags: (args['tags'] as List?)?.cast<String>() ?? existing.tags,
        updatedAt: DateTime.now(),
      ),
    );
    return _toolJson({
      ...snippetToJson(result!.snippet),
      if (result.indexingError != null)
        'indexingWarning': '${result.indexingError}',
    });
  }

  Future<Map<String, dynamic>> _deleteSnippet(Map<String, dynamic> args) async {
    final id = (args['id'] as num?)?.toInt();
    if (id == null) return _toolError('id is required');

    final deleted = await snippets.delete(id);
    if (deleted == 0) return _toolError('snippet #$id not found');
    return _toolText('Deleted snippet #$id.');
  }

  Future<Map<String, dynamic>> _searchMemories(Map<String, dynamic> args) =>
      _searchMemoriesWithMode(args, MemorySearchMode.hybrid);

  Future<Map<String, dynamic>> _searchMemoriesSemantic(
    Map<String, dynamic> args,
  ) => _searchMemoriesWithMode(args, MemorySearchMode.semantic);

  Future<Map<String, dynamic>> _searchMemoriesByTime(
    Map<String, dynamic> args,
  ) => _searchMemoriesWithMode(args, MemorySearchMode.temporal);

  Future<Map<String, dynamic>> _searchMemoriesWithMode(
    Map<String, dynamic> args,
    MemorySearchMode mode,
  ) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) return _toolError('query is required');
    final limit = _memoryLimit(args, 10);
    if (limit == null) {
      return _toolError('limit must be between 1 and $maxMcpMemoryResults');
    }
    final result = await memory.searchMemory(
      query,
      limit: limit,
      mode: mode,
      filters: _memoryFilters(args),
    );
    return _toolJson({
      'memories': result.evidence.map(_evidenceJson).toList(),
      if (result.semanticError != null)
        'semanticWarning': '${result.semanticError}',
    });
  }

  Future<Map<String, dynamic>> _getMemoryEpisode(
    Map<String, dynamic> args,
  ) async {
    final id = (args['id'] as num?)?.toInt();
    if (id == null) return _toolError('id is required');
    final episode = await memory.getEpisode(id);
    if (episode == null) return _toolError('memory episode #$id not found');
    return _toolJson(_episodeJson(episode));
  }

  Future<Map<String, dynamic>> _listRecentMemories(
    Map<String, dynamic> args,
  ) async {
    final limit = _memoryLimit(args, 20);
    if (limit == null) {
      return _toolError('limit must be between 1 and $maxMcpMemoryResults');
    }
    final episodes = await memory.recentEpisodes(limit: limit);
    return _toolJson(episodes.map(_episodeJson).toList());
  }

  Future<Map<String, dynamic>> _findRelatedMemories(
    Map<String, dynamic> args,
  ) async {
    final id = (args['id'] as num?)?.toInt();
    if (id == null) return _toolError('id is required');
    final episode = await memory.getEpisode(id);
    if (episode == null) return _toolError('memory episode #$id not found');
    final limit = _memoryLimit(args, 10);
    if (limit == null) {
      return _toolError('limit must be between 1 and $maxMcpMemoryResults');
    }
    final query = [episode.title, ...episode.topics].join(' ');
    final result = await memory.searchEpisodes(query, limit: limit + 1);
    return _toolJson(
      result.matches
          .where((match) => match.episode.id != id)
          .take(limit)
          .map((match) => _episodeJson(match.episode))
          .toList(),
    );
  }

  Future<Map<String, dynamic>> _investigateMemory(
    Map<String, dynamic> args,
  ) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) return _toolError('query is required');
    final memoryAgent = agent;
    if (memoryAgent == null) {
      return _toolError('agentic memory is not available');
    }
    final provider = llmProvider;
    if (provider != null) {
      return _toolJson(
        (await memoryAgent.run(
          provider: provider,
          query: query,
          surface: ConnectorSurface.mcp,
        )).toJson(),
      );
    }
    return _toolJson((await memoryAgent.investigate(query)).toJson());
  }

  Future<Map<String, dynamic>> _deepStudy(Map<String, dynamic> args) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) return _toolError('query is required');
    final memoryAgent = agent;
    if (memoryAgent == null) {
      return _toolError('agentic memory is not available');
    }
    final provider = llmProvider;
    if (provider != null) {
      final run = await memoryAgent.run(
        provider: provider,
        query: query,
        depth: MemoryInvestigationDepth.deep,
        surface: ConnectorSurface.mcp,
      );
      return _toolJson({
        'report': run.answer,
        'stopReason': run.stopReason.name,
        'stepCount': run.stepCount,
        'investigation': run.investigation.toJson(),
      });
    }
    final report = await memoryAgent.deepStudy(query);
    return _toolJson({
      'report': report.markdown,
      'investigation': report.investigation.toJson(),
    });
  }

  Future<Map<String, dynamic>> _searchEntities(
    Map<String, dynamic> args, {
    required bool projectsOnly,
  }) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) return _toolError('query is required');
    final limit = _memoryLimit(args, 20);
    if (limit == null) {
      return _toolError('limit must be between 1 and $maxMcpMemoryResults');
    }
    final normalized = query.toLowerCase();
    final result = await memory.searchEpisodes(query, limit: limit);
    final entities = <String>{};
    for (final match in result.matches) {
      for (final entity in match.episode.entities) {
        final lowered = entity.toLowerCase();
        if ((!projectsOnly || lowered.startsWith('project:')) &&
            lowered.contains(normalized)) {
          entities.add(entity);
        }
      }
    }
    return _toolJson(entities.take(limit).toList());
  }

  Future<Map<String, dynamic>> _forgetMemory(Map<String, dynamic> args) async {
    final id = (args['id'] as num?)?.toInt();
    if (id == null) return _toolError('id is required');
    if (await memory.forgetEpisode(id) == 0) {
      return _toolError('memory episode #$id not found');
    }
    return _toolText('Deleted memory episode #$id.');
  }

  Future<Map<String, dynamic>> _getDailySummary(
    Map<String, dynamic> args,
  ) async {
    final day = _summaryDate(args);
    if (day == null) return _toolError('date must be an ISO date');
    return _summariesFor(day, day.add(const Duration(days: 1)));
  }

  Future<Map<String, dynamic>> _getWeeklySummary(
    Map<String, dynamic> args,
  ) async {
    final day = _summaryDate(args);
    if (day == null) return _toolError('date must be an ISO date');
    final start = day.subtract(Duration(days: day.weekday - DateTime.monday));
    return _summariesFor(start, start.add(const Duration(days: 7)));
  }

  DateTime? _summaryDate(Map<String, dynamic> args) {
    final raw = args['date'];
    final now = DateTime.now();
    if (raw == null) return DateTime(now.year, now.month, now.day);
    if (raw is! String) return null;
    final parsed = DateTime.tryParse(raw);
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  Future<Map<String, dynamic>> _summariesFor(
    DateTime start,
    DateTime end,
  ) async => _toolJson({
    'rangeStart': start.toIso8601String(),
    'rangeEnd': end.toIso8601String(),
    'summaries':
        (await memory.summariesBetween(start, end)).map(_summaryJson).toList(),
  });

  Future<Map<String, dynamic>> _askLtm(Map<String, dynamic> args) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) return _toolError('query is required');
    final keywords = (args['keywords'] as String?)?.trim() ?? '';

    final memoryAgent = agent;
    final provider = llmProvider;
    if (memoryAgent != null && provider != null) {
      final run = await memoryAgent.run(
        provider: provider,
        query:
            keywords.isEmpty
                ? query
                : '$query\nPalavras-chave para a busca: $keywords',
        history: _history(args['history']),
        depth:
            args['deepStudy'] == true
                ? MemoryInvestigationDepth.deep
                : MemoryInvestigationDepth.standard,
        surface: ConnectorSurface.mcp,
      );
      return _toolJson(run.toJson());
    }

    final range = parseTemporalRange(query);
    final queryEnd = range.end.add(const Duration(seconds: 1));
    final activities =
        keywords.isEmpty
            ? (await memory.between(
              range.start,
              queryEnd,
            )).take(maxLtmActivities).toList()
            : await memory.search(
              keywords,
              start: range.start,
              end: queryEnd,
              limit: maxLtmActivities,
            );
    final summaries = await memory.summariesBetween(range.start, queryEnd);
    final memoryResult = await memory.searchMemory(query, limit: 20);

    return _toolJson({
      'rangeStart': range.start.toIso8601String(),
      'rangeEnd': range.end.toIso8601String(),
      'activities': activities.map((a) => a.toJson()).toList(),
      'episodes':
          memoryResult.matches
              .map((match) => _episodeJson(match.episode))
              .toList(),
      'evidence': memoryResult.evidence.map(_evidenceJson).toList(),
      'summaries': summaries.map(_summaryJson).toList(),
      if (memoryResult.semanticError != null)
        'semanticWarning': '${memoryResult.semanticError}',
    });
  }

  List<LlmMessage> _history(Object? value) {
    if (value is! List) return const [];
    final messages = <LlmMessage>[];
    for (final raw in value) {
      if (raw is! Map) continue;
      final item = raw.cast<String, dynamic>();
      final content = (item['content'] as String?)?.trim() ?? '';
      final role = switch (item['role']) {
        'user' => LlmRole.user,
        'assistant' => LlmRole.assistant,
        _ => null,
      };
      if (role != null && content.isNotEmpty) {
        messages.add(LlmMessage(role: role, content: content));
      }
    }
    return messages;
  }

  Future<Map<String, dynamic>> _createMemory(Map<String, dynamic> args) async {
    final content = (args['content'] as String?)?.trim() ?? '';
    if (content.isEmpty) return _toolError('content is required');

    return _toolJson(_summaryJson(await memory.remember(content)));
  }

  Map<String, dynamic> _summaryJson(ActivitySummary summary) => {
    ...summary.toJson(),
    'kind': summary.kind.name,
  };

  Map<String, dynamic> _episodeJson(MemoryEpisode episode) => {
    'id': episode.id,
    'startedAt': episode.startedAt.toIso8601String(),
    'endedAt': episode.endedAt.toIso8601String(),
    'title': episode.title,
    'summary': episode.summary,
    'applications': episode.applications,
    'urls': episode.urls,
    'topics': episode.topics,
    'entities': episode.entities,
    'formationVersion': episode.formationVersion,
    'contentHash': episode.contentHash,
    'status': episode.formationStatus.name,
    'confidence': episode.confidence,
    'decisions': episode.decisions,
    'actionItems': episode.actionItems,
    'technologies': episode.technologies,
    'formationModelId': episode.formationModelId,
    'sourceActivityIds': episode.sourceActivityIds,
  };

  Map<String, dynamic> _evidenceJson(MemorySearchEvidence evidence) => {
    'id': evidence.id,
    'source': evidence.source.name,
    'sourceId': evidence.sourceId,
    'title': evidence.title,
    'content': evidence.content,
    'startedAt': evidence.startedAt.toIso8601String(),
    'endedAt': evidence.endedAt.toIso8601String(),
    'score': evidence.score,
    'matchReasons': evidence.matchReasons,
    'applications': evidence.applications,
    'modalities': evidence.modalities.map((item) => item.name).toList(),
    'projects': evidence.projects,
    'semanticSimilarity': evidence.semanticSimilarity,
  };

  MemorySearchFilters _memoryFilters(Map<String, dynamic> args) =>
      MemorySearchFilters(
        sources: _enumSet(
          args['sources'],
          MemoryEvidenceSource.values,
          (item) => item.name,
        ),
        applications: _stringSet(args['applications']),
        modalities: _enumSet(
          args['modalities'],
          MemoryModality.values,
          (item) => item.name,
        ),
        projects: _stringSet(args['projects']),
        start: _optionalDate(args['start']),
        end: _optionalDate(args['end']),
      );

  String? _normalize(String? value) =>
      value == null || value.isEmpty ? null : value;
}

int? _memoryLimit(Map<String, dynamic> args, int defaultValue) {
  final raw = args['limit'];
  if (raw == null) return defaultValue;
  if (raw is! num || !raw.isFinite || raw != raw.roundToDouble()) return null;
  final limit = raw.toInt();
  return limit >= 1 && limit <= maxMcpMemoryResults ? limit : null;
}

Set<String> _stringSet(Object? raw) {
  if (raw == null) return const {};
  if (raw is! List) throw ArgumentError.value(raw, 'filter');
  return raw
      .map((item) {
        if (item is! String) throw ArgumentError.value(item, 'filter item');
        return item.trim();
      })
      .where((item) => item.isNotEmpty)
      .toSet();
}

Set<T> _enumSet<T>(Object? raw, List<T> values, String Function(T item) name) {
  final selected = _stringSet(raw);
  final resolved = {
    for (final value in values)
      if (selected.contains(name(value))) value,
  };
  if (resolved.length != selected.length) {
    throw ArgumentError.value(
      selected,
      'filter',
      'contains unsupported values',
    );
  }
  return resolved;
}

DateTime? _optionalDate(Object? raw) {
  if (raw == null) return null;
  if (raw is! String) throw ArgumentError.value(raw, 'date');
  return DateTime.parse(raw);
}

Map<String, dynamic> _toolText(String text) => {
  'content': [
    {'type': 'text', 'text': text},
  ],
};

Map<String, dynamic> _toolJson(Object data) => _toolText(jsonEncode(data));

Map<String, dynamic> _toolError(String message) => {
  'content': [
    {'type': 'text', 'text': message},
  ],
  'isError': true,
};

Map<String, dynamic> _result(dynamic id, Map<String, dynamic> result) => {
  'jsonrpc': '2.0',
  'id': id,
  'result': result,
};

Map<String, dynamic> _error(dynamic id, int code, String message) => {
  'jsonrpc': '2.0',
  'id': id,
  'error': {'code': code, 'message': message},
};
