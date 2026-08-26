import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kangoos_core/kangoos_core.dart';

import '../capture/capture_settings_repository.dart';
import '../capture/capture_status.dart';
import '../capture/capture_status_indicator.dart';
import '../confirm_dialog.dart';
import '../settings_repository.dart';
import '../snippet_editor_screen.dart';
import 'chat_home_panel.dart';
import 'sidebar.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.snippetRepository,
    required this.snippets,
    required this.memory,
    required this.conversations,
    required this.captureSettingsRepository,
    this.captureStatus,
    this.needsCaptureConsent = false,
    this.onRestoreStaged,
  });

  final SnippetRepository snippetRepository;
  final SnippetService snippets;
  final MemoryService memory;
  final ConversationRepository conversations;
  final CaptureSettingsRepository captureSettingsRepository;
  final CaptureStatusController? captureStatus;
  final bool needsCaptureConsent;
  final Future<void> Function()? onRestoreStaged;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _desktopBreakpoint = 980.0;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _settingsRepository = SettingsRepository();
  late final _summarizer = ActivitySummarizer(
    activities: widget.memory.activities,
    summaries: widget.memory.summaries,
  );
  Snippet? _editingSnippet;
  var _editing = false;
  var _editorDirty = false;

  @override
  void initState() {
    super.initState();
    if (widget.needsCaptureConsent) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _resolveCaptureConsent(),
      );
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
    await widget.captureSettingsRepository.save(
      current.copyWith(paused: enable != true),
    );
  }

  Future<SummaryResult> _generateDayRecap(CancelToken cancelToken) async {
    final settings = await _settingsRepository.load();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _summarizer.summarize(
      provider: settings.buildProvider(),
      kind: SummaryKind.dayRecap,
      start: startOfDay,
      end: now,
      cancelToken: cancelToken,
    );
  }

  Future<void> _openEditor([Snippet? snippet]) async {
    if (_editorDirty) {
      final l10n = AppLocalizations.of(context);
      final discard = await confirmDestructiveAction(
        context: context,
        title: l10n.discardChangesTitle,
        body: l10n.discardChangesBody,
        confirmLabel: l10n.discardChangesConfirm,
      );
      if (!discard) return;
    }
    setState(() {
      _editorDirty = false;
      _editingSnippet = snippet;
      _editing = true;
    });
  }

  void _closeEditor() {
    setState(() {
      _editorDirty = false;
      _editing = false;
      _editingSnippet = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= _desktopBreakpoint;
        if (desktop) {
          return Scaffold(
            body: Row(
              children: [
                _buildSidebar(width: 352),
                Expanded(child: _buildContent()),
              ],
            ),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          drawer: Drawer(
            width: 352,
            child: SafeArea(child: _buildSidebar(closeAfterSelection: true)),
          ),
          body: _buildContent(
            onOpenNavigation: () => _scaffoldKey.currentState?.openDrawer(),
          ),
        );
      },
    );
  }

  Widget _buildSidebar({double? width, bool closeAfterSelection = false}) {
    void closeDrawer() {
      if (closeAfterSelection) _scaffoldKey.currentState?.closeDrawer();
    }

    return Sidebar(
      width: width,
      snippets: widget.snippets,
      memory: widget.memory,
      onSelectSnippet: (snippet) {
        closeDrawer();
        _openEditor(snippet);
      },
      onCreateSnippet: () {
        closeDrawer();
        _openEditor();
      },
      onGenerateDayRecap: _generateDayRecap,
    );
  }

  Widget _buildContent({VoidCallback? onOpenNavigation}) {
    final Widget content;
    if (_editing) {
      content = SnippetEditorScreen(
        key: ValueKey(_editingSnippet?.id ?? 'new'),
        snippets: widget.snippets,
        settingsRepository: _settingsRepository,
        snippet: _editingSnippet,
        onDone: _closeEditor,
        onDirtyChanged: (dirty) => _editorDirty = dirty,
      );
    } else {
      content = ChatHomePanel(
        snippetRepository: widget.snippetRepository,
        snippets: widget.snippets,
        memory: widget.memory,
        conversations: widget.conversations,
        settingsRepository: _settingsRepository,
        captureSettingsRepository: widget.captureSettingsRepository,
        onRestoreStaged: widget.onRestoreStaged,
        onOpenNavigation: onOpenNavigation,
      );
    }

    final captureStatus = widget.captureStatus;
    if (captureStatus == null) return content;
    return Column(
      children: [
        CaptureStatusIndicator(controller: captureStatus),
        Expanded(child: content),
      ],
    );
  }
}
