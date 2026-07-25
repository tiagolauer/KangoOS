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

  try {
    final text = _focusedElementText();
    if (text == null || text.isEmpty) exit(1);
    stdout.write(
      text.length > maxCapturedTextLength
          ? text.substring(0, maxCapturedTextLength)
          : text,
    );
    exit(0);
  } catch (_) {
    exit(1);
  } finally {
    CoUninitialize();
  }
}

String? _focusedElementText() {
  final automation =
      IUIAutomation(COMObject.createFromID(CLSID_CUIAutomation, IID_IUIAutomation));

  final elementPtrPtr = calloc<Pointer<COMObject>>();
  try {
    final hr = automation.getFocusedElement(elementPtrPtr);
    if (FAILED(hr) || elementPtrPtr.value == nullptr) return null;

    final element = IUIAutomationElement(elementPtrPtr.value);

    final valueText = _valuePatternText(element);
    if (valueText != null && valueText.isNotEmpty) return valueText;

    return element.currentName.toDartString();
  } finally {
    free(elementPtrPtr);
  }
}

String? _valuePatternText(IUIAutomationElement element) {
  final patternPtrPtr = calloc<Pointer<COMObject>>();
  try {
    final hr = element.getCurrentPattern(uiaValuePatternId, patternPtrPtr);
    if (FAILED(hr) || patternPtrPtr.value == nullptr) return null;

    return IUIAutomationValuePattern(patternPtrPtr.value)
        .currentValue
        .toDartString();
  } finally {
    free(patternPtrPtr);
  }
}
