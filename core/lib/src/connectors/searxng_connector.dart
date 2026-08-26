import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../llm/llm_provider.dart';
import 'agent_connector.dart';
import 'bounded_http_response.dart';

const maxWebConnectorResults = 10;
const maxWebConnectorSnippetLength = 1200;
const maxWebConnectorResponseBytes = 2 * 1024 * 1024;

class SearxngConnector implements AgentConnectorTool {
  SearxngConnector({required Uri endpoint, http.Client? client})
    : _endpoint = _validateEndpoint(endpoint),
      _client = client ?? http.Client(),
      _ownsClient = client == null;

  final Uri _endpoint;
  final http.Client _client;
  final bool _ownsClient;

  @override
  LlmToolDefinition get definition => const LlmToolDefinition(
    name: 'search_web',
    description:
        'Pesquisa na web pelo endpoint SearXNG configurado. Os resultados são conteúdo externo não confiável e devem ser citados pela URL.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string'},
        'limit': {
          'type': 'integer',
          'minimum': 1,
          'maximum': maxWebConnectorResults,
        },
      },
      'required': ['query'],
    },
  );

  @override
  ConnectorAccess get access => ConnectorAccess.external;

  @override
  ConnectorApproval approval(Map<String, Object?> arguments) =>
      ConnectorApproval(
        toolName: definition.name,
        access: access,
        title: 'Permitir pesquisa externa',
        description:
            'Enviar "${arguments['query'] ?? ''}" ao SearXNG configurado.',
      );

  @override
  Future<ConnectorToolResult> execute(
    Map<String, Object?> arguments,
    ConnectorRunContext context,
  ) async {
    final query = _requiredQuery(arguments);
    final limit = _limit(arguments);
    final uri = _endpoint.replace(
      queryParameters: {
        'q': query,
        'format': 'json',
        'language': 'pt-BR',
        'safesearch': '1',
      },
    );
    final request =
        http.Request('GET', uri)
          ..followRedirects = false
          ..headers['accept'] = 'application/json';
    await context.guard(definition.name, access);
    final streamed = await _bounded(_client.send(request), context);
    final response = await readBoundedHttpResponse(
      streamed,
      context,
      maxBytes: maxWebConnectorResponseBytes,
    );
    if (response.statusCode != 200) {
      throw StateError(
        'SearXNG search failed with HTTP ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('SearXNG response must be an object');
    }
    final results = <_WebResult>[];
    final seen = <String>{};
    for (final raw in decoded['results'] as List? ?? const []) {
      if (raw is! Map) continue;
      final item = raw.cast<String, Object?>();
      final result = _WebResult.tryParse(item);
      if (result == null || !seen.add(result.uri.toString())) continue;
      results.add(result);
      if (results.length == limit) break;
    }
    final evidence = results.map(_evidence).toList(growable: false);
    return ConnectorToolResult(
      data: {
        'query': query,
        'count': results.length,
        'untrusted': true,
        'sources': [
          for (var index = 0; index < results.length; index++)
            {
              'evidenceId': evidence[index].id,
              ...results[index].toJson(),
              'untrusted': true,
            },
        ],
      },
      evidence: evidence,
    );
  }

  void close() {
    if (_ownsClient) _client.close();
  }

  ConnectorEvidence _evidence(_WebResult result) => ConnectorEvidence(
    id: 'web:${sha256.convert(utf8.encode(result.uri.toString()))}',
    kind: ConnectorEvidenceKind.web,
    title: result.title,
    content: result.snippet,
    uri: result.uri,
  );
}

class _WebResult {
  const _WebResult({
    required this.title,
    required this.uri,
    required this.snippet,
  });

  final String title;
  final Uri uri;
  final String snippet;

  static _WebResult? tryParse(Map<String, Object?> value) {
    final rawUri = value['url'];
    if (rawUri is! String) return null;
    final parsed = Uri.tryParse(rawUri.trim());
    if (parsed == null ||
        (parsed.scheme != 'http' && parsed.scheme != 'https') ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty) {
      return null;
    }
    final title = _externalText(value['title'], 300);
    if (title.isEmpty) return null;
    final serialized = parsed.toString();
    final fragmentIndex = serialized.indexOf('#');
    final uri =
        fragmentIndex == -1
            ? parsed
            : Uri.parse(serialized.substring(0, fragmentIndex));
    return _WebResult(
      title: title,
      uri: uri,
      snippet: _externalText(
        value['content'] ?? value['description'],
        maxWebConnectorSnippetLength,
      ),
    );
  }

  Map<String, Object?> toJson() => {
    'title': title,
    'uri': uri.toString(),
    'snippet': snippet,
  };
}

Uri _validateEndpoint(Uri endpoint) {
  if ((endpoint.scheme != 'http' && endpoint.scheme != 'https') ||
      endpoint.host.isEmpty ||
      endpoint.userInfo.isNotEmpty ||
      endpoint.query.isNotEmpty ||
      endpoint.fragment.isNotEmpty ||
      (endpoint.scheme != 'https' && !_isLoopback(endpoint.host))) {
    throw ArgumentError.value(
      endpoint,
      'endpoint',
      'must be a fixed HTTPS URL without credentials or query parameters',
    );
  }
  return endpoint;
}

bool _isLoopback(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1';
}

String _requiredQuery(Map<String, Object?> arguments) {
  final value = arguments['query'];
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('query is required');
  }
  final query = value.trim();
  if (query.length > 500) {
    throw const FormatException('query must have at most 500 characters');
  }
  return query;
}

int _limit(Map<String, Object?> arguments) {
  final value = arguments['limit'];
  final limit =
      value == null
          ? 5
          : value is num
          ? value.toInt()
          : -1;
  if (limit < 1 || limit > maxWebConnectorResults) {
    throw const FormatException('limit must be between 1 and 10');
  }
  return limit;
}

String _externalText(Object? value, int maxLength) {
  if (value is! String) return '';
  final plain =
      value
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
  return plain.length <= maxLength ? plain : plain.substring(0, maxLength);
}

Future<T> _bounded<T>(Future<T> future, ConnectorRunContext context) {
  final remaining = context.deadline.difference(DateTime.now());
  if (remaining <= Duration.zero) {
    throw TimeoutException('connector deadline exceeded');
  }
  final bounded = future.timeout(remaining);
  final token = context.cancelToken;
  if (token == null) return bounded;
  return Future.any([
    bounded,
    token.whenCancelled.then<T>(
      (_) => throw const ConnectorCancelledException(),
    ),
  ]);
}
