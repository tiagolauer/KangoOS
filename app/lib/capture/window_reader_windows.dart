import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

import 'window_snapshot.dart';

WindowSnapshot? readForegroundWindowWindows() {
  final hwnd = GetForegroundWindow();
  if (hwnd == 0) return null;

  final title = _windowTitle(hwnd);
  if (title == null || title.trim().isEmpty) return null;

  final identity = _processIdentity(hwnd);
  return WindowSnapshot(
    appId: identity.id,
    appName: identity.name,
    windowTitle: title,
    nativeWindowId: hwnd,
  );
}

String? _windowTitle(int hwnd) {
  final length = GetWindowTextLength(hwnd);
  if (length == 0) return null;

  final buffer = wsalloc(length + 1);
  try {
    GetWindowText(hwnd, buffer, length + 1);
    return buffer.toDartString();
  } finally {
    free(buffer);
  }
}

_ProcessIdentity _processIdentity(int hwnd) {
  final pidPtr = calloc<Uint32>();
  final int pid;
  try {
    GetWindowThreadProcessId(hwnd, pidPtr);
    pid = pidPtr.value;
  } finally {
    free(pidPtr);
  }

  final process = OpenProcess(
    PROCESS_ACCESS_RIGHTS.PROCESS_QUERY_LIMITED_INFORMATION,
    0,
    pid,
  );
  if (process == 0) {
    return _ProcessIdentity(id: 'windows:pid:$pid', name: 'pid:$pid');
  }

  try {
    final sizePtr = calloc<Uint32>()..value = MAX_PATH;
    final nameBuffer = wsalloc(MAX_PATH);
    try {
      final ok = QueryFullProcessImageName(process, 0, nameBuffer, sizePtr);
      if (ok == 0) {
        return _ProcessIdentity(id: 'windows:pid:$pid', name: 'pid:$pid');
      }
      final executable = p.normalize(nameBuffer.toDartString());
      return _ProcessIdentity(
        id: 'windows:${executable.toLowerCase()}',
        name: p.basename(executable),
      );
    } finally {
      free(sizePtr);
      free(nameBuffer);
    }
  } finally {
    CloseHandle(process);
  }
}

class _ProcessIdentity {
  const _ProcessIdentity({required this.id, required this.name});

  final String id;
  final String name;
}
