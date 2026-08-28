import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_app/runtime/kango_runtime.dart';
import 'package:kangoos_app/runtime/runtime_service.dart';

void main() {
  test('starts once and stops services once in reverse order', () async {
    final events = <String>[];
    final runtime = KangoRuntime(
      services: [
        _TestService('capture', events),
        _TestService('summary', events),
        _TestService('tray', events),
      ],
      onStopped: () async => events.add('stopped'),
    );

    await runtime.start();
    await runtime.start();
    await runtime.stop();
    await runtime.stop();

    expect(events, [
      'start:capture',
      'start:summary',
      'start:tray',
      'stop:tray',
      'stop:summary',
      'stop:capture',
      'stopped',
    ]);
  });

  test('rolls back every entered service when startup fails', () async {
    final events = <String>[];
    final runtime = KangoRuntime(
      services: [
        _TestService('capture', events),
        _TestService('summary', events, failStart: true),
      ],
      onStopped: () async => events.add('stopped'),
    );

    await expectLater(runtime.start(), throwsStateError);

    expect(events, [
      'start:capture',
      'start:summary',
      'stop:summary',
      'stop:capture',
      'stopped',
    ]);
  });
}

class _TestService implements RuntimeService {
  _TestService(this.name, this.events, {this.failStart = false});

  final String name;
  final List<String> events;
  final bool failStart;

  @override
  Future<void> start() async {
    events.add('start:$name');
    if (failStart) throw StateError('$name failed');
  }

  @override
  Future<void> stop() async => events.add('stop:$name');
}
