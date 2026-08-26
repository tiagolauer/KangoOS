import 'dart:ffi';
import 'dart:io';

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
  } catch (error, stackTrace) {
    stderr.writeln('Browser URL capture failed: $error\n$stackTrace');
    return null;
  }
}

String? _addressBarText(int hwnd) {
  final comInitResult =
      CoInitializeEx(nullptr, COINIT.COINIT_APARTMENTTHREADED);
  final ownsCom = SUCCEEDED(comInitResult);
  CUIAutomation? automation;
  try {
    automation = CUIAutomation.createInstance();

    final elementPtr = calloc<COMObject>();
    IUIAutomationElement? root;
    try {
      var hr = automation.elementFromHandle(hwnd, elementPtr.cast());
      if (FAILED(hr) || elementPtr.ref.isNull) return null;
      root = IUIAutomationElement(elementPtr);

      final conditionPtr = calloc<COMObject>();
      IUIAutomationCondition? condition;
      final typeVariant = calloc<VARIANT>();
      try {
        VariantInit(typeVariant);
        typeVariant.ref
          ..vt = VARENUM.VT_I4
          ..lVal = UIA_CONTROLTYPE_ID.UIA_EditControlTypeId;

        hr = automation.createPropertyCondition(
          UIA_PROPERTY_ID.UIA_ControlTypePropertyId,
          typeVariant.ref,
          conditionPtr.cast(),
        );
        if (FAILED(hr) || conditionPtr.ref.isNull) return null;
        condition = IUIAutomationCondition(conditionPtr);

        final foundPtr = calloc<COMObject>();
        IUIAutomationElement? edit;
        try {
          hr = root.findFirst(
            TreeScope.TreeScope_Descendants,
            condition.ptr.ref.lpVtbl.cast(),
            foundPtr.cast(),
          );
          if (FAILED(hr) || foundPtr.ref.isNull) return null;
          edit = IUIAutomationElement(foundPtr);

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
            free(valueVariant);
          }
        } finally {
          if (edit == null) {
            free(foundPtr);
          } else {
            _disposeComObject(edit);
          }
        }
      } finally {
        VariantClear(typeVariant);
        free(typeVariant);
        if (condition == null) {
          free(conditionPtr);
        } else {
          _disposeComObject(condition);
        }
      }
    } finally {
      if (root == null) {
        free(elementPtr);
      } else {
        _disposeComObject(root);
      }
    }
  } finally {
    if (automation != null) _disposeComObject(automation);
    if (ownsCom) CoUninitialize();
  }
}

void _disposeComObject(IUnknown object) {
  object.detach();
  object.release();
  free(object.ptr);
}

final _urlLike = RegExp(r'^([a-zA-Z][a-zA-Z\d+.-]*://|[\w-]+\.[a-z]{2,})');

bool _looksLikeUrl(String value) => _urlLike.hasMatch(value.trim());
