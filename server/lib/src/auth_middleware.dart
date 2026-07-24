import 'dart:convert';

import 'package:shelf/shelf.dart';

Middleware authMiddleware(String apiToken) {
  return (Handler innerHandler) {
    return (Request request) {
      if (request.url.path == 'health') return innerHandler(request);

      if (request.headers['authorization'] != 'Bearer $apiToken') {
        return Response.forbidden(
          jsonEncode({'error': 'missing or invalid bearer token'}),
          headers: {'content-type': 'application/json'},
        );
      }
      return innerHandler(request);
    };
  };
}
