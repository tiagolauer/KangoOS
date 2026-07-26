import 'dart:convert';

import 'package:shelf/shelf.dart';

Middleware authMiddleware(String apiToken) {
  return (Handler innerHandler) {
    return (Request request) {
      if (request.url.path == 'health') return innerHandler(request);

      final header = request.headers['authorization'] ?? '';
      if (!constantTimeEquals(header, 'Bearer $apiToken')) {
        return Response(
          401,
          body: jsonEncode({'error': 'missing or invalid bearer token'}),
          headers: {
            'content-type': 'application/json',
            'www-authenticate': 'Bearer',
          },
        );
      }
      return innerHandler(request);
    };
  };
}

bool constantTimeEquals(String a, String b) {
  final aBytes = utf8.encode(a);
  final bBytes = utf8.encode(b);
  if (bBytes.isEmpty) return aBytes.isEmpty;
  var diff = aBytes.length ^ bBytes.length;
  for (var i = 0; i < aBytes.length; i++) {
    diff |= aBytes[i] ^ bBytes[i % bBytes.length];
  }
  return diff == 0;
}
