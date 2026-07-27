import 'dart:async';

/// Hands a caller a way to stop an in-flight LLM stream. Cancelling keeps
/// whatever text already arrived instead of discarding it.
class CancelToken {
  final _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

Future<String> collectLlmReply(
  Stream<String> chunks, {
  CancelToken? cancelToken,
  void Function(String partial)? onPartial,
}) {
  if (cancelToken?.isCancelled ?? false) return Future.value('');

  final buffer = StringBuffer();
  final completer = Completer<String>();
  final subscription = chunks.listen(
    (chunk) {
      buffer.write(chunk);
      onPartial?.call(buffer.toString());
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) completer.completeError(error, stackTrace);
    },
    onDone: () {
      if (!completer.isCompleted) completer.complete(buffer.toString());
    },
    cancelOnError: true,
  );

  final cancelled = cancelToken?.whenCancelled;
  if (cancelled != null) {
    unawaited(cancelled.then((_) {
      if (!completer.isCompleted) completer.complete(buffer.toString());
    }));
  }

  return completer.future
      .whenComplete(() => unawaited(subscription.cancel()));
}
