import 'package:flutter/foundation.dart';

import 'capture_environment.dart';

class CaptureRuntimeStatus {
  const CaptureRuntimeStatus({
    this.microphoneActive = false,
    this.ocrActive = false,
    this.systemLocked = false,
    this.userIdle = false,
  });

  final bool microphoneActive;
  final bool ocrActive;
  final bool systemLocked;
  final bool userIdle;

  CaptureRuntimeStatus copyWith({
    bool? microphoneActive,
    bool? ocrActive,
    bool? systemLocked,
    bool? userIdle,
  }) =>
      CaptureRuntimeStatus(
        microphoneActive: microphoneActive ?? this.microphoneActive,
        ocrActive: ocrActive ?? this.ocrActive,
        systemLocked: systemLocked ?? this.systemLocked,
        userIdle: userIdle ?? this.userIdle,
      );

  @override
  bool operator ==(Object other) =>
      other is CaptureRuntimeStatus &&
      microphoneActive == other.microphoneActive &&
      ocrActive == other.ocrActive &&
      systemLocked == other.systemLocked &&
      userIdle == other.userIdle;

  @override
  int get hashCode =>
      Object.hash(microphoneActive, ocrActive, systemLocked, userIdle);
}

class CaptureStatusController extends ValueNotifier<CaptureRuntimeStatus> {
  CaptureStatusController() : super(const CaptureRuntimeStatus());

  void setMicrophoneActive(bool active) =>
      _set(value.copyWith(microphoneActive: active));

  void setOcrActive(bool active) => _set(value.copyWith(ocrActive: active));

  void setEnvironment(CaptureEnvironmentState environment, {bool? idle}) =>
      _set(value.copyWith(systemLocked: environment.locked, userIdle: idle));

  void _set(CaptureRuntimeStatus status) {
    if (status != value) value = status;
  }
}
