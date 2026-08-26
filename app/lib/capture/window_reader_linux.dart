import 'dart:convert';
import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

import 'window_snapshot.dart';

typedef _XOpenDisplayNative = ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf8>);
typedef _XDefaultRootWindowNative = ffi.Uint64 Function(ffi.Pointer<ffi.Void>);
typedef _XDefaultRootWindowDart = int Function(ffi.Pointer<ffi.Void>);
typedef _XInternAtomNative = ffi.Uint64 Function(
    ffi.Pointer<ffi.Void>, ffi.Pointer<Utf8>, ffi.Int32);
typedef _XInternAtomDart = int Function(
    ffi.Pointer<ffi.Void>, ffi.Pointer<Utf8>, int);
typedef _XGetWindowPropertyNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Void>,
  ffi.Uint64,
  ffi.Uint64,
  ffi.Int64,
  ffi.Int64,
  ffi.Int32,
  ffi.Uint64,
  ffi.Pointer<ffi.Uint64>,
  ffi.Pointer<ffi.Int32>,
  ffi.Pointer<ffi.Uint64>,
  ffi.Pointer<ffi.Uint64>,
  ffi.Pointer<ffi.Pointer<ffi.Uint8>>,
);
typedef _XGetWindowPropertyDart = int Function(
  ffi.Pointer<ffi.Void>,
  int,
  int,
  int,
  int,
  int,
  int,
  ffi.Pointer<ffi.Uint64>,
  ffi.Pointer<ffi.Int32>,
  ffi.Pointer<ffi.Uint64>,
  ffi.Pointer<ffi.Uint64>,
  ffi.Pointer<ffi.Pointer<ffi.Uint8>>,
);
typedef _XFetchNameNative = ffi.Int32 Function(
    ffi.Pointer<ffi.Void>, ffi.Uint64, ffi.Pointer<ffi.Pointer<Utf8>>);
typedef _XFetchNameDart = int Function(
    ffi.Pointer<ffi.Void>, int, ffi.Pointer<ffi.Pointer<Utf8>>);
typedef _XVoidPointerArgNative = ffi.Int32 Function(ffi.Pointer<ffi.Void>);
typedef _XVoidPointerArgDart = int Function(ffi.Pointer<ffi.Void>);

class _X11 {
  _X11(ffi.DynamicLibrary lib)
      : openDisplay =
            lib.lookupFunction<_XOpenDisplayNative, _XOpenDisplayNative>(
                'XOpenDisplay'),
        defaultRootWindow = lib.lookupFunction<_XDefaultRootWindowNative,
            _XDefaultRootWindowDart>('XDefaultRootWindow'),
        internAtom = lib.lookupFunction<_XInternAtomNative, _XInternAtomDart>(
            'XInternAtom'),
        getWindowProperty = lib.lookupFunction<_XGetWindowPropertyNative,
            _XGetWindowPropertyDart>('XGetWindowProperty'),
        fetchName = lib
            .lookupFunction<_XFetchNameNative, _XFetchNameDart>('XFetchName'),
        xFree =
            lib.lookupFunction<_XVoidPointerArgNative, _XVoidPointerArgDart>(
                'XFree'),
        closeDisplay =
            lib.lookupFunction<_XVoidPointerArgNative, _XVoidPointerArgDart>(
                'XCloseDisplay');

  final ffi.Pointer<ffi.Void> Function(ffi.Pointer<Utf8>) openDisplay;
  final int Function(ffi.Pointer<ffi.Void>) defaultRootWindow;
  final int Function(ffi.Pointer<ffi.Void>, ffi.Pointer<Utf8>, int) internAtom;
  final _XGetWindowPropertyDart getWindowProperty;
  final int Function(ffi.Pointer<ffi.Void>, int, ffi.Pointer<ffi.Pointer<Utf8>>)
      fetchName;
  final int Function(ffi.Pointer<ffi.Void>) xFree;
  final int Function(ffi.Pointer<ffi.Void>) closeDisplay;
}

_X11? _bindings;
var _loadAttempted = false;

_X11? _loadX11() {
  if (_loadAttempted) return _bindings;
  _loadAttempted = true;
  for (final name in ['libX11.so.6', 'libX11.so']) {
    try {
      _bindings = _X11(ffi.DynamicLibrary.open(name));
      break;
    } catch (_) {
      // Try the next candidate name.
    }
  }
  return _bindings;
}

WindowSnapshot? readForegroundWindowLinux() {
  final x11 = _loadX11();
  if (x11 == null) return null;

  try {
    final display = x11.openDisplay(ffi.nullptr);
    if (display == ffi.nullptr) return null;

    try {
      final root = x11.defaultRootWindow(display);
      final activeWindow = _activeWindowId(x11, display, root);
      if (activeWindow == null) return null;

      final title = _fetchTitle(x11, display, activeWindow);
      if (title == null || title.trim().isEmpty) return null;

      final appName = _fetchWmClass(x11, display, activeWindow) ?? 'unknown';
      return WindowSnapshot(
        appId: 'linux:${appName.toLowerCase()}',
        appName: appName,
        windowTitle: title,
        nativeWindowId: activeWindow,
      );
    } finally {
      x11.closeDisplay(display);
    }
  } catch (_) {
    return null;
  }
}

int? _activeWindowId(_X11 x11, ffi.Pointer<ffi.Void> display, int root) {
  final atom = _internAtom(x11, display, '_NET_ACTIVE_WINDOW');
  if (atom == 0) return null;

  final value = _readProperty32(x11, display, root, atom);
  return value == null || value == 0 ? null : value;
}

String? _fetchTitle(_X11 x11, ffi.Pointer<ffi.Void> display, int window) {
  final netWmName = _internAtom(x11, display, '_NET_WM_NAME');
  if (netWmName != 0) {
    final bytes = _readTextProperty(x11, display, window, netWmName);
    if (bytes != null && bytes.isNotEmpty) return bytes;
  }
  return _fetchNameLegacy(x11, display, window);
}

String? _fetchNameLegacy(_X11 x11, ffi.Pointer<ffi.Void> display, int window) {
  final namePtr = calloc<ffi.Pointer<Utf8>>();
  try {
    final status = x11.fetchName(display, window, namePtr);
    if (status == 0 || namePtr.value == ffi.nullptr) return null;
    final name = namePtr.value.toDartString();
    x11.xFree(namePtr.value.cast());
    return name;
  } finally {
    calloc.free(namePtr);
  }
}

String? _fetchWmClass(_X11 x11, ffi.Pointer<ffi.Void> display, int window) {
  final atom = _internAtom(x11, display, 'WM_CLASS');
  if (atom == 0) return null;

  final bytes = _readPropertyBytes(x11, display, window, atom);
  if (bytes == null || bytes.isEmpty) return null;

  final parts = utf8
      .decode(bytes, allowMalformed: true)
      .split('\x00')
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return null;
  return parts.length > 1 ? parts[1] : parts.first;
}

int _internAtom(_X11 x11, ffi.Pointer<ffi.Void> display, String name) {
  final namePtr = name.toNativeUtf8();
  try {
    return x11.internAtom(display, namePtr, 1);
  } finally {
    calloc.free(namePtr);
  }
}

String? _readTextProperty(
    _X11 x11, ffi.Pointer<ffi.Void> display, int window, int atom) {
  final bytes = _readPropertyBytes(x11, display, window, atom);
  if (bytes == null) return null;
  return utf8.decode(bytes, allowMalformed: true);
}

/// Reads an X11 window property whose value fits a single 32-bit slot
/// (stored as a full C `long`, i.e. 8 bytes on 64-bit Linux).
int? _readProperty32(
    _X11 x11, ffi.Pointer<ffi.Void> display, int window, int atom) {
  final actualType = calloc<ffi.Uint64>();
  final actualFormat = calloc<ffi.Int32>();
  final nitems = calloc<ffi.Uint64>();
  final bytesAfter = calloc<ffi.Uint64>();
  final prop = calloc<ffi.Pointer<ffi.Uint8>>();
  try {
    final status = x11.getWindowProperty(
      display,
      window,
      atom,
      0,
      1,
      0,
      0,
      actualType,
      actualFormat,
      nitems,
      bytesAfter,
      prop,
    );
    if (status != 0 || nitems.value < 1 || prop.value == ffi.nullptr) {
      return null;
    }
    final value = prop.value.cast<ffi.Uint64>().value;
    x11.xFree(prop.value.cast());
    return value;
  } finally {
    calloc.free(actualType);
    calloc.free(actualFormat);
    calloc.free(nitems);
    calloc.free(bytesAfter);
    calloc.free(prop);
  }
}

List<int>? _readPropertyBytes(
    _X11 x11, ffi.Pointer<ffi.Void> display, int window, int atom) {
  final actualType = calloc<ffi.Uint64>();
  final actualFormat = calloc<ffi.Int32>();
  final nitems = calloc<ffi.Uint64>();
  final bytesAfter = calloc<ffi.Uint64>();
  final prop = calloc<ffi.Pointer<ffi.Uint8>>();
  try {
    final status = x11.getWindowProperty(
      display,
      window,
      atom,
      0,
      1024,
      0,
      0,
      actualType,
      actualFormat,
      nitems,
      bytesAfter,
      prop,
    );
    if (status != 0 || nitems.value < 1 || prop.value == ffi.nullptr) {
      return null;
    }
    final bytes = List<int>.of(prop.value.asTypedList(nitems.value));
    x11.xFree(prop.value.cast());
    return bytes;
  } finally {
    calloc.free(actualType);
    calloc.free(actualFormat);
    calloc.free(nitems);
    calloc.free(bytesAfter);
    calloc.free(prop);
  }
}
