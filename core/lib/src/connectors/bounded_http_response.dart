import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'agent_connector.dart';

Future<http.Response> readBoundedHttpResponse(
  http.StreamedResponse response,
  ConnectorRunContext context, {
  required int maxBytes,
}) async {
  if (maxBytes <= 0) {
    throw ArgumentError.value(maxBytes, 'maxBytes', 'must be positive');
  }
  if (response.contentLength case final contentLength?
      when contentLength > maxBytes) {
    await response.stream.listen(null).cancel();
    throw const HttpResponseTooLargeException();
  }
  final remaining = context.deadline.difference(DateTime.now());
  if (remaining <= Duration.zero) {
    await response.stream.listen(null).cancel();
    throw TimeoutException('connector deadline exceeded');
  }
  if (context.cancelToken?.isCancelled ?? false) {
    await response.stream.listen(null).cancel();
    throw const ConnectorCancelledException();
  }

  final body = BytesBuilder(copy: false);
  final completed = Completer<Uint8List>();
  late final StreamSubscription<List<int>> subscription;
  Timer? deadlineTimer;

  void fail(Object error, [StackTrace? stackTrace]) {
    if (completed.isCompleted) return;
    if (stackTrace == null) {
      completed.completeError(error);
    } else {
      completed.completeError(error, stackTrace);
    }
    unawaited(subscription.cancel());
  }

  subscription = response.stream.listen(
    (chunk) {
      if (body.length + chunk.length > maxBytes) {
        fail(const HttpResponseTooLargeException());
        return;
      }
      body.add(chunk);
    },
    onError: fail,
    onDone: () {
      if (!completed.isCompleted) completed.complete(body.takeBytes());
    },
    cancelOnError: true,
  );
  deadlineTimer = Timer(
    remaining,
    () => fail(TimeoutException('connector deadline exceeded')),
  );
  final cancelled = context.cancelToken?.whenCancelled;
  if (cancelled != null) {
    unawaited(cancelled.then((_) => fail(const ConnectorCancelledException())));
  }

  final bytes = await completed.future.whenComplete(() {
    deadlineTimer?.cancel();
    unawaited(subscription.cancel());
  });
  return http.Response.bytes(
    bytes,
    response.statusCode,
    request: response.request,
    headers: response.headers,
    isRedirect: response.isRedirect,
    persistentConnection: response.persistentConnection,
    reasonPhrase: response.reasonPhrase,
  );
}

class HttpResponseTooLargeException implements Exception {
  const HttpResponseTooLargeException();

  @override
  String toString() => 'Connector HTTP response exceeds the allowed size';
}
