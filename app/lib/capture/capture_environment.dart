import 'dart:io';

import 'package:flutter/services.dart';

class CaptureEnvironmentState {
  const CaptureEnvironmentState({
    this.locked = false,
    this.idleFor = Duration.zero,
  });

  final bool locked;
  final Duration idleFor;
}

typedef CaptureEnvironmentReader = Future<CaptureEnvironmentState> Function();

class CaptureEnvironment {
  static const _channel = MethodChannel('kangoos/window');

  static Future<CaptureEnvironmentState> read() async {
    if (!Platform.isWindows) return const CaptureEnvironmentState();
    final value = await _channel.invokeMapMethod<String, Object?>(
      'getCaptureEnvironment',
    );
    if (value == null) {
      throw StateError('Windows capture environment returned no value.');
    }
    return CaptureEnvironmentState(
      locked: value['locked'] as bool? ?? false,
      idleFor: Duration(
        milliseconds: (value['idleMilliseconds'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
