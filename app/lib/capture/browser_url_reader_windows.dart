import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

const _browserProcessNames = {'chrome.exe', 'msedge.exe', 'brave.exe'};

/// Best-effort: locates the address bar via UI Automation and reads its
/// text. Chromium's internal accessibility tree isn't a documented/stable
/// contract, so this assumes the address bar is the first Edit control
/// found in the window — true in current Chrome/Edge/Brave, but a browser
/// update could move it. Falls back to null on any mismatch or failure,
/// it never throws out to the caller.
String? readBrowserUrlWindows(String appName) {
  if (!_browserProcessNames.contains(appName.toLowerCase())) return null;

  try {
    final hwnd = GetForegroundWindow();
    if (hwnd == 0) return null;
    return _addressBarText(hwnd);
  } catch (_) {
    return null;
  }
}

String? _addressBarText(int hwnd) {
  final comInitResult =
      CoInitializeEx(nullptr, COINIT.COINIT_APARTMENTTHREADED);
  final ownsCom = SUCCEEDED(comInitResult);
  try {
    final automation = CUIAutomation.createInstance();

    final elementPtr = calloc<Pointer<COMObject>>();
    try {
      var hr = automation.elementFromHandle(hwnd, elementPtr);
      if (FAILED(hr) || elementPtr.value == nullptr) return null;
      final root = IUIAutomationElement(elementPtr.value);

      final conditionPtr = calloc<Pointer<COMObject>>();
      final typeVariant = calloc<VARIANT>();
      try {
        VariantInit(typeVariant);
        typeVariant.ref
          ..vt = VARENUM.VT_I4
          ..lVal = UIA_CONTROLTYPE_ID.UIA_EditControlTypeId;

        hr = automation.createPropertyCondition(
          UIA_PROPERTY_ID.UIA_ControlTypePropertyId,
          typeVariant.ref,
          conditionPtr,
        );
        if (FAILED(hr) || conditionPtr.value == nullptr) return null;
        final condition = IUIAutomationCondition(conditionPtr.value);

        final foundPtr = calloc<Pointer<COMObject>>();
        try {
          hr = root.findFirst(
              TreeScope.TreeScope_Descendants, condition.ptr, foundPtr);
          if (FAILED(hr) || foundPtr.value == nullptr) return null;
          final edit = IUIAutomationElement(foundPtr.value);

          final valueVariant = calloc<VARIANT>();
          try {
            VariantInit(valueVariant);
            hr = edit.getCurrentPropertyValue(
              UIA_PROPERTY_ID.UIA_ValueValuePropertyId,
              valueVariant,
            );
            if (FAILED(hr) || valueVariant.ref.vt != VARENUM.VT_BSTR) {
              return null;
            }

            final value = valueVariant.ref.bstrVal.toDartString();
            return _looksLikeUrl(value) ? value : null;
          } finally {
            VariantClear(valueVariant);
            calloc.free(valueVariant);
          }
        } finally {
          calloc.free(foundPtr);
        }
      } finally {
        VariantClear(typeVariant);
        calloc.free(typeVariant);
        calloc.free(conditionPtr);
      }
    } finally {
      calloc.free(elementPtr);
    }
  } finally {
    if (ownsCom) CoUninitialize();
  }
}

final _urlLike = RegExp(r'^([a-zA-Z][a-zA-Z\d+.-]*://|[\w-]+\.[a-z]{2,})');

bool _looksLikeUrl(String value) => _urlLike.hasMatch(value.trim());
