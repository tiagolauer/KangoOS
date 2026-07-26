import 'dart:io';

import 'package:win32_registry/win32_registry.dart';

const _runKeyPath = r'Software\Microsoft\Windows\CurrentVersion\Run';
const _runValueName = 'KangoOS';

class AutostartService {
  static bool get isSupported => Platform.isWindows;

  bool isEnabled() {
    if (!isSupported) return false;
    final key = Registry.openPath(RegistryHive.currentUser, path: _runKeyPath);
    try {
      return key.getValueAsString(_runValueName) != null;
    } finally {
      key.close();
    }
  }

  void setEnabled(bool enabled) {
    if (!isSupported) return;
    final key = Registry.openPath(
      RegistryHive.currentUser,
      path: _runKeyPath,
      desiredAccessRights: AccessRights.allAccess,
    );
    try {
      if (enabled) {
        key.createValue(RegistryValue(
          _runValueName,
          RegistryValueType.string,
          '"${Platform.resolvedExecutable}"',
        ));
      } else if (key.getValueAsString(_runValueName) != null) {
        key.deleteValue(_runValueName);
      }
    } finally {
      key.close();
    }
  }
}
