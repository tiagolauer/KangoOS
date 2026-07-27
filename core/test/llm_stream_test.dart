import 'dart:async';

import 'package:kangoos_core/kangoos_core.dart';
import 'package:test/test.dart';

void main() {
  test('cancelling mid-stream resolves with the text that already arrived',
      () async {
    final chunks = StreamController<String>();
    final cancelToken = CancelToken();
    final reply = collectLlmReply(chunks.stream, cancelToken: cancelToken);

    chunks.add('half an ');
    await Future<void>.delayed(Duration.zero);
    cancelToken.cancel();

    expect(await reply, 'half an ');
    expect(chunks.hasListener, isFalse);
  });

  test('a token cancelled before the call short-circuits', () async {
    var subscribed = false;
    final cancelToken = CancelToken()..cancel();
    final chunks = Stream<String>.multi((_) => subscribed = true);

    expect(await collectLlmReply(chunks, cancelToken: cancelToken), '');
    expect(subscribed, isFalse);
  });

  test('reports partials as they arrive and returns the whole reply', () async {
    final partials = <String>[];
    final reply = await collectLlmReply(
      Stream.fromIterable(['one ', 'two']),
      onPartial: partials.add,
    );

    expect(partials, ['one ', 'one two']);
    expect(reply, 'one two');
  });

  test('a failing stream propagates the error', () {
    expect(
      collectLlmReply(Stream<String>.error(StateError('stream died'))),
      throwsStateError,
    );
  });
}
