class WindowSnapshot {
  const WindowSnapshot({
    required this.appName,
    required this.windowTitle,
    String? appId,
    this.nativeWindowId,
  }) : appId = appId ?? appName;

  final String appId;
  final String appName;
  final String windowTitle;
  final int? nativeWindowId;

  bool isSameTarget(WindowSnapshot other) =>
      appId == other.appId &&
      (nativeWindowId == null ||
          other.nativeWindowId == null ||
          nativeWindowId == other.nativeWindowId);
}
