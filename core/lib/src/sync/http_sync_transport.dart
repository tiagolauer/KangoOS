import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sync_transport.dart';

class HttpSyncTransport implements SyncTransport {
  HttpSyncTransport({
    required this.baseUrl,
    required this.apiToken,
    http.Client? client,
  }) : client = client ?? http.Client();

  final Uri baseUrl;
  final String apiToken;
  final http.Client client;

  Map<String, String> get _headers => {
        'authorization': 'Bearer $apiToken',
        'content-type': 'application/json',
      };

  @override
  Future<List<SyncSnippet>> fetchSnippets() async {
    final response = await client.get(
      baseUrl.resolve('/snippets'),
      headers: _headers,
    );
    _expect(response, 200, 'fetch remote snippets');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const SyncException('Remote snippets response must be a list.');
    }
    return decoded.map(_decodeSnippet).toList();
  }

  @override
  Future<List<SyncTombstone>> fetchTombstones() async {
    final response = await client.get(
      baseUrl.resolve('/snippets/deleted'),
      headers: _headers,
    );
    if (response.statusCode == 404) return const [];
    _expect(response, 200, 'fetch remote deletions');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const SyncException('Remote deletions response must be a list.');
    }
    return decoded.map((entry) {
      if (entry is! Map<String, dynamic>) {
        throw const SyncException('Remote deletion entry must be an object.');
      }
      return SyncTombstone(
        syncId: _string(entry, 'syncId'),
        deletedAt: _timestamp(entry, 'deletedAt'),
      );
    }).toList();
  }

  @override
  Future<void> createSnippet(SyncSnippet snippet) async {
    final response = await client.post(
      baseUrl.resolve('/snippets'),
      headers: _headers,
      body: jsonEncode(_encodeSnippet(snippet)),
    );
    _expect(response, 200, 'push snippet');
  }

  @override
  Future<void> updateSnippet(int remoteId, SyncSnippet snippet) async {
    final response = await client.put(
      baseUrl.resolve('/snippets/$remoteId'),
      headers: _headers,
      body: jsonEncode(_encodeSnippet(snippet)),
    );
    _expect(response, 200, 'push snippet update');
  }

  @override
  Future<void> deleteSnippet(String syncId) async {
    final response = await client.delete(
      baseUrl.resolve('/snippets/by-sync-id/$syncId'),
      headers: _headers,
    );
    if (response.statusCode != 204 && response.statusCode != 404) {
      throw SyncException(
        'Failed to delete remote snippet: ${response.statusCode}.',
      );
    }
  }

  SyncSnippet _decodeSnippet(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const SyncException('Remote snippet entry must be an object.');
    }
    final tags = raw['tags'];
    if (tags is! List || tags.any((tag) => tag is! String)) {
      throw const SyncException('Remote snippet tags must be strings.');
    }
    return SyncSnippet(
      remoteId: _integer(raw, 'id'),
      title: _string(raw, 'title'),
      content: _string(raw, 'content'),
      language: raw['language'] as String?,
      tags: tags.cast<String>(),
      syncId: _string(raw, 'syncId'),
      createdAt: _timestamp(raw, 'createdAt'),
      updatedAt: _timestamp(raw, 'updatedAt'),
    );
  }

  Map<String, dynamic> _encodeSnippet(SyncSnippet snippet) => {
        'title': snippet.title,
        'content': snippet.content,
        'language': snippet.language,
        'tags': snippet.tags,
        'syncId': snippet.syncId,
        'createdAt': snippet.createdAt.millisecondsSinceEpoch,
        'updatedAt': snippet.updatedAt.millisecondsSinceEpoch,
      };

  void _expect(http.Response response, int status, String operation) {
    if (response.statusCode != status) {
      throw SyncException(
        'Failed to $operation: ${response.statusCode}.',
      );
    }
  }

  String _string(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw SyncException('Remote field "$key" must be a non-empty string.');
    }
    return value;
  }

  int _integer(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! int) {
      throw SyncException('Remote field "$key" must be an integer.');
    }
    return value;
  }

  DateTime _timestamp(Map<String, dynamic> map, String key) =>
      DateTime.fromMillisecondsSinceEpoch(_integer(map, key));
}
