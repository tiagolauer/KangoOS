import 'runtime_service.dart';

class KangoRuntime {
  KangoRuntime({required this.services, this.onStopped});

  final List<RuntimeService> services;
  final Future<void> Function()? onStopped;
  final _started = <RuntimeService>[];
  bool _stopped = false;

  Future<void> start() async {
    if (_started.isNotEmpty) return;
    _stopped = false;
    try {
      for (final service in services) {
        _started.add(service);
        await service.start();
      }
    } catch (error, stackTrace) {
      try {
        await stop();
      } catch (cleanupError) {
        Error.throwWithStackTrace(
          StateError(
            'Runtime start failed: $error; cleanup failed: $cleanupError',
          ),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    Object? firstError;
    StackTrace? firstStackTrace;
    for (final service in _started.reversed) {
      try {
        await service.stop();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }
    _started.clear();
    try {
      await onStopped?.call();
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }
}
