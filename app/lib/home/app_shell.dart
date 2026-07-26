import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
    this.needsCaptureConsent = false,
  });

  final KangoosDatabase database;
  final SemanticSearch semanticSearch;
  final CaptureSettingsRepository captureSettingsRepository;
  final bool needsCaptureConsent;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _settingsRepository = SettingsRepository();
  late final _summarizer = ActivitySummarizer(database: widget.database);
  Snippet? _editingSnippet;
  var _editing = false;

  @override
  void initState() {
    super.initState();
    if (widget.needsCaptureConsent) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _resolveCaptureConsent());
    }
  }

  Future<void> _resolveCaptureConsent() async {
    final enable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.activityCapture),
          content: Text(
            '${l10n.captureConsentBody}\n\n${l10n.captureConsentPrivacy}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonNotNow),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.commonEnable),
            ),
          ],
        );
      },
    );

    await widget.captureSettingsRepository.markConsentShown();
    final current = await widget.captureSettingsRepository.load();
    await widget.captureSettingsRepository
        .save(current.copyWith(paused: enable != true));
  }

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
