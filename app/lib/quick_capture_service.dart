import 'package:flutter/services.dart' show Clipboard, PlatformException;
import 'package:kangoos_core/kangoos_core.dart';

import 'capture/window_capture_service.dart';

class QuickCaptureService {
  QuickCaptureService({
    required this.database,
    required this.semanticSearch,
    Future<String?> Function()? readClipboard,
    WindowSnapshot? Function()? readWindow,
  })  : readClipboard = readClipboard ?? _readClipboardText,
        readWindow = readWindow ?? WindowCaptureService.defaultWindowReader();

  final KangoosDatabase database;
  final SemanticSearch semanticSearch;
  final Future<String?> Function() readClipboard;
  final WindowSnapshot? Function() readWindow;

  Future<int?> saveClipboard() async {
    final clipboard = (await readClipboard())?.trim() ?? '';
    if (clipboard.isEmpty) return null;

    final entry = buildQuickCapture(
      clipboard: clipboard,
      sourceApp: readWindow()?.appName,
    );
    final id = await database.createSnippet(entry);

    final saved = await database.getSnippetById(id);
    if (saved != null) {
      await semanticSearch.indexSnippet(saved).catchError((Object _) {});
    }
    return id;
  }

  static Future<String?> _readClipboardText() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } on PlatformException {
      return null;
    }
  }
}
