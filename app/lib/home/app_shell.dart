import 'package:flutter/material.dart';
import 'package:kangoos_core/kangoos_core.dart';

import '../capture/capture_settings_repository.dart';
import '../settings_repository.dart';
import '../snippet_editor_screen.dart';
import 'chat_home_panel.dart';
import 'sidebar.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.database,
    required this.semanticSearch,
    required this.captureSettingsRepository,
  });

  final KangoosDatabase database;
  final SemanticSearch semanticSearch;
  final CaptureSettingsRepository captureSettingsRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _settingsRepository = SettingsRepository();
  late final _summarizer = ActivitySummarizer(database: widget.database);
  Snippet? _editingSnippet;
  var _editing = false;

  Future<SummaryResult> _generateDayRecap() async {
    final settings = await _settingsRepository.load();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _summarizer.summarize(
      provider: settings.buildProvider(),
      kind: SummaryKind.dayRecap,
      start: startOfDay,
      end: now,
    );
  }

  void _openEditor([Snippet? snippet]) {
    setState(() {
      _editingSnippet = snippet;
      _editing = true;
    });
  }

  void _closeEditor() {
    setState(() {
      _editing = false;
      _editingSnippet = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            database: widget.database,
            semanticSearch: widget.semanticSearch,
            onSelectSnippet: _openEditor,
            onCreateSnippet: () => _openEditor(),
            onGenerateDayRecap: _generateDayRecap,
          ),
          Expanded(
            child: _editing
                ? SnippetEditorScreen(
                    key: ValueKey(_editingSnippet?.id ?? 'new'),
                    database: widget.database,
                    semanticSearch: widget.semanticSearch,
                    settingsRepository: _settingsRepository,
                    snippet: _editingSnippet,
                    onDone: _closeEditor,
                  )
                : ChatHomePanel(
                    database: widget.database,
                    semanticSearch: widget.semanticSearch,
                    settingsRepository: _settingsRepository,
                    captureSettingsRepository: widget.captureSettingsRepository,
                  ),
          ),
        ],
      ),
    );
  }
}
