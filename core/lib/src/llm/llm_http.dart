import 'dart:convert';

import 'package:http/http.dart' as http;

const defaultLlmTimeout = Duration(seconds: 90);

const _maxErrorBodyChars = 500;

class LlmException implements Exception {
  const LlmException({
    required this.provider,
    required this.statusCode,
    required this.message,
  });

  final String provider;
  final int statusCode;
  final String message;

  @override
  String toString() => '$provider request failed (HTTP $statusCode): $message';
}

Future<http.StreamedResponse> sendLlmRequest({
  required http.Client client,
  required http.Request request,
  required String provider,
  required Duration timeout,
}) async {
  final response = await client.send(request).timeout(timeout);
  if (response.statusCode >= 200 && response.statusCode < 300) return response;

  final body = await response.stream.bytesToString().timeout(timeout);
  throw LlmException(
    provider: provider,
    statusCode: response.statusCode,
    message: _errorMessage(body),
  );
}

String _errorMessage(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return 'empty response body';

  final decoded = _tryDecodeJson(trimmed);
  if (decoded is Map<String, dynamic>) {
    final error = decoded['error'];
    if (error is String && error.isNotEmpty) return error;
    if (error is Map<String, dynamic> && error['message'] is String) {
      return error['message'] as String;
    }
    if (decoded['message'] is String) return decoded['message'] as String;
  }

  if (trimmed.length <= _maxErrorBodyChars) return trimmed;
  return '${trimmed.substring(0, _maxErrorBodyChars)}...';
}

Object? _tryDecodeJson(String body) {
  try {
    return jsonDecode(body);
  } on FormatException {
    return null;
  }
}
