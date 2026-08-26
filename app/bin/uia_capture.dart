import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

const maxCapturedTextLength = 2000;
const coinitApartmentThreaded = 0x2;
const uiaValuePatternId = 10002;

void main() {
  final hr = CoInitializeEx(nullptr, coinitApartmentThreaded);
  if (FAILED(hr) && hr != S_FALSE) exit(1);

  var exitCode = 1;
  try {
    final text = _focusedElementText();
    if (text != null && text.isNotEmpty) {
      stdout.write(
        text.length > maxCapturedTextLength
            ? text.substring(0, maxCapturedTextLength)
            : text,
      );
      exitCode = 0;
    }
  } catch (error, stackTrace) {
    stderr.writeln('UI Automation capture failed: $error\n$stackTrace');
  } finally {
    CoUninitialize();
  }
  exit(exitCode);
}

String? _focusedElementText() {
  final automation = IUIAutomation(
      COMObject.createFromID(CLSID_CUIAutomation, IID_IUIAutomation));

  final elementPtr = calloc<COMObject>();
  IUIAutomationElement? element;
  try {
    final hr = automation.getFocusedElement(elementPtr.cast());
    if (FAILED(hr) || elementPtr.ref.isNull) return null;

    element = IUIAutomationElement(elementPtr);

    final valueText = _valuePatternText(element);
    if (valueText != null && valueText.isNotEmpty) return valueText;

    return _readAndFreeBstr(element.currentName);
  } finally {
    if (element == null) {
      free(elementPtr);
    } else {
      _disposeComObject(element);
    }
    _disposeComObject(automation);
  }
}

String? _valuePatternText(IUIAutomationElement element) {
  final patternPtr = calloc<COMObject>();
  IUIAutomationValuePattern? pattern;
  try {
    final hr = element.getCurrentPattern(uiaValuePatternId, patternPtr.cast());
    if (FAILED(hr) || patternPtr.ref.isNull) return null;

    pattern = IUIAutomationValuePattern(patternPtr);
    return _readAndFreeBstr(pattern.currentValue);
  } finally {
    if (pattern == null) {
      free(patternPtr);
    } else {
      _disposeComObject(pattern);
    }
  }
}

String? _readAndFreeBstr(Pointer<Utf16> value) {
  if (value == nullptr) return null;
  try {
    return value.toDartString();
  } finally {
    SysFreeString(value);
  }
}

void _disposeComObject(IUnknown object) {
  object.detach();
  object.release();
  free(object.ptr);
}
