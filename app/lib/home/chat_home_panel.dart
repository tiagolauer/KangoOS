import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kangoos_core/kangoos_core.dart';

import '../capture/capture_settings_repository.dart';
import '../capture/capture_settings_screen.dart';
import '../confirm_dialog.dart';
import '../copy_button.dart';
import '../llm_error.dart';
import '../settings_repository.dart';
import '../settings_screen.dart';
import '../sync/sync_settings_repository.dart';
import '../sync/sync_settings_screen.dart';
import '../theme/kangoos_theme.dart';
import 'activity_sparkline.dart';
import 'markdown_message.dart';

enum _AccentRole { primary, done, next, later }

Color _accentColor(
    _AccentRole role, ColorScheme colors, KangoosStatusColors status) {
  switch (role) {
    case _AccentRole.primary:
      return colors.primary;
    case _AccentRole.done:
      return status.done;
    case _AccentRole.next:
      return status.next;
    case _AccentRole.later:
      return status.later;
  }
}

class _SummaryAction {
  const _SummaryAction({
    required this.icon,
    required this.title,
    required this.description,
    required this.prompt,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String description;
  final String prompt;
  final _AccentRole accent;
}

List<_SummaryAction> _summaryActionsFor(AppLocalizations l10n) => [
      _SummaryAction(
        icon: Icons.wb_sunny_outlined,
        title: l10n.actionDayRecapTitle,
        description: l10n.actionDayRecapDescription,
        prompt: l10n.actionDayRecapPrompt,
        accent: _AccentRole.primary,
      ),
      _SummaryAction(
        icon: Icons.forum_outlined,
        title: l10n.actionStandupTitle,
        description: l10n.actionStandupDescription,
        prompt: l10n.actionStandupPrompt,
        accent: _AccentRole.later,
      ),
      _SummaryAction(
        icon: Icons.code_outlined,
        title: l10n.actionRecentSnippetsTitle,
        description: l10n.actionRecentSnippetsDescription,
        prompt: l10n.actionRecentSnippetsPrompt,
        accent: _AccentRole.done,
      ),
      _SummaryAction(
        icon: Icons.sell_outlined,
        title: l10n.actionMissingTagsTitle,
        description: l10n.actionMissingTagsDescription,
        prompt: l10n.actionMissingTagsPrompt,
        accent: _AccentRole.next,
      ),
      _SummaryAction(
        icon: Icons.insights_outlined,
        title: l10n.actionTopOfMindTitle,
        description: l10n.actionTopOfMindDescription,
        prompt: l10n.actionTopOfMindPrompt,
        accent: _AccentRole.done,
      ),
      _SummaryAction(
        icon: Icons.schedule_outlined,
        title: l10n.actionTimeBreakdownTitle,
        description: l10n.actionTimeBreakdownDescription,
        prompt: l10n.actionTimeBreakdownPrompt,
        accent: _AccentRole.primary,
      ),
    ];

List<String> _freeformPoolFor(AppLocalizations l10n) => [
      l10n.freeform1,
      l10n.freeform2,
      l10n.freeform3,
      l10n.freeform4,
      l10n.freeform5,
    ];

String? _osUserName() {
  final env = Platform.environment;
  final name = env['USERNAME'] ?? env['USER'] ?? env['LOGNAME'];
  return (name == null || name.trim().isEmpty) ? null : name.trim();
}

class ChatHomePanel extends StatefulWidget {
  const ChatHomePanel({
    super.key,
    required this.snippetRepository,
    required this.snippets,
    required this.memory,
    required this.conversations,
    required this.settingsRepository,
    required this.captureSettingsRepository,
    this.providerBuilder,
    this.onOpenNavigation,
    this.onRestoreStaged,
  });

  final SnippetRepository snippetRepository;
  final SnippetService snippets;
  final MemoryService memory;
  final ConversationRepository conversations;
  final SettingsRepository settingsRepository;
  final CaptureSettingsRepository captureSettingsRepository;
  final VoidCallback? onOpenNavigation;
  final Future<void> Function()? onRestoreStaged;

  /// Overridable for tests; defaults to [LlmSettings.buildProvider].
  final LlmProvider Function(LlmSettings settings)? providerBuilder;

  @override
  State<ChatHomePanel> createState() => _ChatHomePanelState();
}

class _ChatHomePanelState extends State<ChatHomePanel> {
  late final _ragChat = RagChat(
    snippets: widget.snippets,
    memory: widget.memory,
    agent: MemoryAgent(
      memory: widget.memory,
      snippets: widget.snippets,
      conversations: widget.conversations,
    ),
    onSemanticSearchError: (_) {
      if (mounted) setState(() => _semanticDegraded = true);
    },
  );
  final _syncSettingsRepository = SyncSettingsRepository();

  final _history = <LlmMessage>[];
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _random = Random();
  var _sending = false;
  var _capturing = true;
  var _semanticDegraded = false;
  var _deepStudy = false;
  CancelToken? _replyCancelToken;
  int? _conversationId;
  String? _error;
  List<String>? _freeformSuggestions;

  bool get _started => _history.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadCaptureState();
    _loadConversation();
  }

  @override
  void dispose() {
    _replyCancelToken?.cancel();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCaptureState() async {
    final settings = await widget.captureSettingsRepository.load();
    if (mounted) setState(() => _capturing = !settings.paused);
  }

  Future<void> _loadConversation() async {
    final id = await widget.conversations.latestId();
    if (id == null || !mounted) return;
    final messages = await widget.conversations.messages(id);
    if (!mounted) return;
    setState(() {
      _conversationId = id;
      _history
        ..clear()
        ..addAll(
            messages.map((m) => LlmMessage(role: m.role, content: m.content)));
    });
  }

  void _startNewChat() {
    setState(() {
      _conversationId = null;
      _history.clear();
      _error = null;
    });
  }

  Future<void> _loadConversationById(int id) async {
    final messages = await widget.conversations.messages(id);
    if (!mounted) return;
    setState(() {
      _conversationId = id;
      _error = null;
      _history
        ..clear()
        ..addAll(
            messages.map((m) => LlmMessage(role: m.role, content: m.content)));
    });
    _scrollToEnd();
  }

  Future<void> _openHistory() async {
    final selectedId = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => ConversationHistorySheet(
        conversations: widget.conversations,
        currentConversationId: _conversationId,
      ),
    );
    if (selectedId != null) await _loadConversationById(selectedId);
    if (_conversationId != null &&
        (await widget.conversations.messages(_conversationId!)).isEmpty &&
        mounted) {
      _startNewChat();
    }
  }

  void _shuffleFreeformSuggestions() {
    final pool = List<String>.of(_freeformPoolFor(AppLocalizations.of(context)))
      ..shuffle(_random);
    setState(() => _freeformSuggestions = pool.take(2).toList());
  }

  Future<void> _indexMissing() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final report = await widget.snippets.indexPending();
      if (report.failures.isNotEmpty) {
        messenger.showSnackBar(SnackBar(
          content: Text(l10n
              .indexingFailed(l10n.failedSnippetCount(report.failures.length))),
        ));
        return;
      }
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.indexedSnippets(report.indexed))));
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.indexingFailed('$e'))));
    }
  }

  Future<void> _exportSnippets() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final exchange = SnippetExchange(
      repository: widget.snippetRepository,
      snippets: widget.snippets,
    );
    try {
      final location = await getSaveLocation(
        suggestedName: 'kangoos-snippets.json',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON', extensions: ['json'])
        ],
      );
      if (location == null) return;
      final json = await exchange.exportJson();
      await XFile.fromData(
        utf8.encode(json),
        mimeType: 'application/json',
      ).saveTo(location.path);
      messenger.showSnackBar(SnackBar(content: Text(l10n.snippetsExported)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed('$e'))));
    }
  }

  Future<void> _importSnippets() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final exchange = SnippetExchange(
      repository: widget.snippetRepository,
      snippets: widget.snippets,
    );
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON', extensions: ['json'])
        ],
      );
      if (file == null) return;
      final result = await exchange.importJson(await file.readAsString());
      if (result.indexingFailures.isNotEmpty) {
        messenger.showSnackBar(SnackBar(
          content: Text(l10n.indexingFailed(
              l10n.failedSnippetCount(result.indexingFailures.length))),
        ));
      }
      messenger.showSnackBar(SnackBar(
          content:
              Text(l10n.importSucceeded(result.imported, result.skipped))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.importFailed('$e'))));
    }
  }

  Future<void> _send(String text) async {
    final l10n = AppLocalizations.of(context);
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;
    setState(() => _semanticDegraded = false);

    final settings = await widget.settingsRepository.load();
    if (settings.model.isEmpty) {
      setState(() => _error = l10n.setModelFirst);
      return;
    }
    if (settings.requiresApiKey && settings.apiKey.isEmpty) {
      setState(() => _error = l10n.setApiKeyFirst);
      return;
    }

    final priorHistory = List<LlmMessage>.of(_history);
    _conversationId ??= await widget.conversations.create();
    final userMessageId = await widget.conversations
        .appendMessage(_conversationId!, LlmRole.user, trimmed);

    final cancelToken = CancelToken();
    setState(() {
      _error = null;
      _history.add(LlmMessage(role: LlmRole.user, content: trimmed));
      _history.add(const LlmMessage(role: LlmRole.assistant, content: ''));
      _inputController.clear();
      _sending = true;
      _replyCancelToken = cancelToken;
    });
    _scrollToEnd();

    final buildProvider = widget.providerBuilder ?? (s) => s.buildProvider();
    final provider = buildProvider(settings);

    var reply = '';
    try {
      reply = await collectLlmReply(
        _ragChat.reply(
          provider: provider,
          history: priorHistory,
          userMessage: trimmed,
          deepStudy: _deepStudy,
        ),
        cancelToken: cancelToken,
        onPartial: (partial) {
          reply = partial;
          if (!mounted) return;
          setState(() {
            _history[_history.length - 1] =
                LlmMessage(role: LlmRole.assistant, content: partial);
          });
          _scrollToEnd();
        },
      );
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = l10n.chatRequestFailed(describeLlmError(l10n, e)));
      }
    } finally {
      await _persistReply(userMessageId, reply, trimmed);
      if (mounted) {
        setState(() {
          _sending = false;
          _replyCancelToken = null;
        });
      }
    }
  }

  void _stopReply() => _replyCancelToken?.cancel();

  Future<void> _persistReply(
      int userMessageId, String reply, String userMessage) async {
    if (reply.isNotEmpty) {
      await widget.conversations
          .appendMessage(_conversationId!, LlmRole.assistant, reply);
      return;
    }

    await widget.conversations.deleteMessage(userMessageId);
    if (!mounted) return;
    setState(() {
      _history.removeLast();
      _history.removeLast();
      _inputController.text = userMessage;
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _Header(
          capturing: _capturing,
          showNewChat: _started,
          onOpenNavigation: widget.onOpenNavigation,
          onNewChat: _startNewChat,
          onOpenHistory: _openHistory,
          onIndexMissing: _indexMissing,
          onOpenCaptureSettings: () async {
            await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CaptureSettingsScreen(
                repository: widget.captureSettingsRepository,
                memory: widget.memory,
                onRestoreStaged: widget.onRestoreStaged,
              ),
            ));
            _loadCaptureState();
          },
          onOpenLlmSettings: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                SettingsScreen(repository: widget.settingsRepository),
          )),
          onOpenSyncSettings: () =>
              Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SyncSettingsScreen(
              repository: _syncSettingsRepository,
              snippetRepository: widget.snippetRepository,
              snippets: widget.snippets,
            ),
          )),
          onExportSnippets: _exportSnippets,
          onImportSnippets: _importSnippets,
        ),
        if (_error != null)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.errorContainer,
            padding: const EdgeInsets.all(8),
            child: Text(
              _error!,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer),
            ),
          ),
        if (_semanticDegraded)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.tertiaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onTertiaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.semanticSearchUnavailable,
                    style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onTertiaryContainer),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
            child: _started
                ? _buildConversation(context)
                : _buildGreeting(context)),
        _Composer(
          controller: _inputController,
          focusNode: _inputFocusNode,
          sending: _sending,
          deepStudy: _deepStudy,
          onDeepStudyChanged: (value) => setState(() => _deepStudy = value),
          onSubmit: _send,
          onStop: _stopReply,
        ),
      ],
    );
  }

  Widget _buildGreeting(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final summaryActions = _summaryActionsFor(l10n);
    final suggestions =
        _freeformSuggestions ?? _freeformPoolFor(l10n).take(2).toList();
    final userName = _osUserName();
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.memoryReady,
            style: textTheme.labelSmall?.copyWith(color: colors.primary)),
        const SizedBox(height: 18),
        Text(
          userName == null ? l10n.greeting : l10n.greetingNamed(userName),
          style: textTheme.headlineLarge,
        ),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(l10n.homeSubtitle,
              style: textTheme.bodyLarge
                  ?.copyWith(color: colors.onSurfaceVariant)),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.lock_outline, size: 15, color: colors.primary),
            const SizedBox(width: 7),
            Text(l10n.localMemory, style: textTheme.labelMedium),
            const SizedBox(width: 16),
            Container(width: 1, height: 16, color: colors.outline),
            const SizedBox(width: 16),
            Flexible(
              child: Text(l10n.memorySources, style: textTheme.labelSmall),
            ),
          ],
        ),
      ],
    );
    final activityPanel = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      color: colors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.nowLabel,
              style: textTheme.labelSmall?.copyWith(color: colors.onPrimary)),
          const SizedBox(height: 22),
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                color: _capturing ? colors.secondary : colors.onPrimary,
              ),
              const SizedBox(width: 9),
              Text(
                _capturing
                    ? l10n.captureActiveStatus
                    : l10n.capturePausedStatus,
                style: textTheme.titleMedium?.copyWith(color: colors.onPrimary),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Text(l10n.todayActivity,
              style: textTheme.labelSmall
                  ?.copyWith(color: colors.onPrimary.withValues(alpha: 0.72))),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final now = DateTime.now();
            final startOfDay = DateTime(now.year, now.month, now.day);
            return StreamBuilder<List<Activity>>(
              stream: widget.memory.watchBetween(
                  startOfDay, startOfDay.add(const Duration(days: 1))),
              builder: (context, snapshot) {
                final hourly =
                    bucketActivityMinutesByHour(snapshot.data ?? const []);
                return ActivitySparkline(
                  hourlyMinutes: hourly,
                  isCapturing: _capturing,
                  foregroundColor: colors.onPrimary,
                  backgroundColor: colors.primary,
                );
              },
            );
          }),
          const SizedBox(height: 18),
          Text(l10n.ptBrStatus,
              style: textTheme.labelSmall?.copyWith(color: colors.onPrimary)),
        ],
      ),
    );
    final quickQuestions = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.sectionFreeformChat, style: textTheme.labelSmall),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: l10n.shuffleSuggestions,
              onPressed: _shuffleFreeformSuggestions,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 6),
        StreamBuilder<List<Snippet>>(
          stream: widget.snippets.watchAll(),
          builder: (context, snapshot) {
            final snippets = snapshot.data;
            final mostRecent = (snippets != null && snippets.isNotEmpty)
                ? snippets.first
                : null;
            final prompts = [
              if (mostRecent != null) l10n.explainSnippet(mostRecent.title),
              ...suggestions,
            ];
            return Column(
              children: [
                for (final prompt in prompts)
                  _FreeformChip(text: prompt, onTap: () => _send(prompt)),
                _StartNewChatChip(onTap: () => _inputFocusNode.requestFocus()),
              ],
            );
          },
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        final pagePadding = compact ? 20.0 : 42.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pagePadding, 36, pagePadding, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        intro,
                        const SizedBox(height: 38),
                        activityPanel,
                        const SizedBox(height: 36),
                        Text(l10n.quickActions, style: textTheme.labelSmall),
                        const SizedBox(height: 8),
                        for (final action in summaryActions)
                          _SummaryActionCard(action: action, onTap: _send),
                        const SizedBox(height: 34),
                        quickQuestions,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              intro,
                              const SizedBox(height: 48),
                              Text(l10n.quickActions,
                                  style: textTheme.labelSmall),
                              const SizedBox(height: 8),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 0,
                                  crossAxisSpacing: 24,
                                  mainAxisExtent: 98,
                                ),
                                itemCount: summaryActions.length,
                                itemBuilder: (context, index) =>
                                    _SummaryActionCard(
                                  action: summaryActions[index],
                                  onTap: _send,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 44),
                        SizedBox(
                          width: 300,
                          child: Column(
                            children: [
                              activityPanel,
                              const SizedBox(height: 28),
                              quickQuestions,
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConversation(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      itemCount: _history.length,
      itemBuilder: (context, index) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: _ChatBubble(
            message: _history[index],
            pending: _sending &&
                index == _history.length - 1 &&
                _history[index].content.isEmpty,
          ),
        ),
      ),
    );
  }
}

enum _HeaderAction { indexSnippets, capture, sync, llm, export, import }

class _Header extends StatelessWidget {
  const _Header({
    required this.capturing,
    required this.showNewChat,
    required this.onNewChat,
    required this.onOpenHistory,
    required this.onIndexMissing,
    required this.onOpenCaptureSettings,
    required this.onOpenLlmSettings,
    required this.onOpenSyncSettings,
    required this.onExportSnippets,
    required this.onImportSnippets,
    this.onOpenNavigation,
  });

  final bool capturing;
  final bool showNewChat;
  final VoidCallback? onOpenNavigation;
  final VoidCallback onNewChat;
  final VoidCallback onOpenHistory;
  final VoidCallback onIndexMissing;
  final VoidCallback onOpenCaptureSettings;
  final VoidCallback onOpenLlmSettings;
  final VoidCallback onOpenSyncSettings;
  final VoidCallback onExportSnippets;
  final VoidCallback onImportSnippets;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 820;
          return Row(
            children: [
              if (onOpenNavigation != null) ...[
                IconButton(
                  onPressed: onOpenNavigation,
                  icon: const Icon(Icons.menu),
                  tooltip:
                      MaterialLocalizations.of(context).openAppDrawerTooltip,
                ),
                const SizedBox(width: 6),
              ],
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.appTitle,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(l10n.workspaceSubtitle,
                      style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
              const Spacer(),
              if (wide) ...[
                Container(
                  width: 7,
                  height: 7,
                  color: capturing ? colors.secondary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  capturing
                      ? l10n.captureActiveStatus
                      : l10n.capturePausedStatus,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(width: 20),
              ],
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: l10n.chatHistory,
                onPressed: onOpenHistory,
              ),
              if (showNewChat) ...[
                const SizedBox(width: 4),
                wide
                    ? FilledButton.icon(
                        onPressed: onNewChat,
                        icon: const Icon(Icons.add_comment_outlined, size: 18),
                        label: Text(l10n.newChat),
                      )
                    : IconButton(
                        onPressed: onNewChat,
                        icon: const Icon(Icons.add_comment_outlined),
                        tooltip: l10n.newChat,
                      ),
              ],
              const SizedBox(width: 4),
              PopupMenuButton<_HeaderAction>(
                tooltip: l10n.more,
                onSelected: _runAction,
                itemBuilder: (context) => [
                  _menuItem(_HeaderAction.indexSnippets,
                      Icons.auto_awesome_outlined, l10n.indexSnippets),
                  _menuItem(_HeaderAction.capture, Icons.privacy_tip_outlined,
                      l10n.captureSettings),
                  _menuItem(
                      _HeaderAction.sync, Icons.sync_outlined, l10n.serverSync),
                  _menuItem(_HeaderAction.llm, Icons.tune, l10n.llmSettings),
                  _menuItem(_HeaderAction.export, Icons.upload_file_outlined,
                      l10n.exportSnippets),
                  _menuItem(_HeaderAction.import, Icons.download_outlined,
                      l10n.importSnippets),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  PopupMenuItem<_HeaderAction> _menuItem(
      _HeaderAction value, IconData icon, String label) {
    return PopupMenuItem<_HeaderAction>(
      value: value,
      child: ListTile(
        leading: Icon(icon, size: 20),
        title: Text(label),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  void _runAction(_HeaderAction action) {
    switch (action) {
      case _HeaderAction.indexSnippets:
        onIndexMissing();
        break;
      case _HeaderAction.capture:
        onOpenCaptureSettings();
        break;
      case _HeaderAction.sync:
        onOpenSyncSettings();
        break;
      case _HeaderAction.llm:
        onOpenLlmSettings();
        break;
      case _HeaderAction.export:
        onExportSnippets();
        break;
      case _HeaderAction.import:
        onImportSnippets();
        break;
    }
  }
}

class ConversationHistorySheet extends StatelessWidget {
  const ConversationHistorySheet({
    super.key,
    required this.conversations,
    required this.currentConversationId,
  });

  final ConversationRepository conversations;
  final int? currentConversationId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: StreamBuilder<List<ConversationSummary>>(
          stream: conversations.watchSummaries(),
          builder: (context, snapshot) {
            final conversations = snapshot.data;
            if (conversations == null) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (conversations.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Text(l10n.noSavedConversations,
                    style: textTheme.bodyMedium),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                return ListTile(
                  selected: conversation.id == currentConversationId,
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: Text(
                    conversation.preview.isEmpty
                        ? l10n.untitledChat
                        : conversation.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(l10n.messageCount(conversation.messageCount)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.commonDelete,
                    onPressed: () async {
                      final confirmed = await confirmDestructiveAction(
                        context: context,
                        title: l10n.deleteConversationTitle,
                        body: l10n.deleteConversationBody(
                            conversation.preview.isEmpty
                                ? l10n.newChat
                                : conversation.preview),
                      );
                      if (confirmed) {
                        await this.conversations.delete(conversation.id);
                      }
                    },
                  ),
                  onTap: () => Navigator.of(context).pop(conversation.id),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SummaryActionCard extends StatelessWidget {
  const _SummaryActionCard({required this.action, required this.onTap});

  final _SummaryAction action;
  final void Function(String prompt) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = Theme.of(context).extension<KangoosStatusColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final accent = _accentColor(action.accent, colors, status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onTap(action.prompt),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colors.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(action.icon, color: accent, size: 20),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      action.title,
                      style: textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      action.description,
                      style: textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.arrow_forward,
                  color: colors.onSurfaceVariant, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreeformChip extends StatelessWidget {
  const _FreeformChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colors.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.north_east, size: 15, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurface, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartNewChatChip extends StatelessWidget {
  const _StartNewChatChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              Icon(Icons.add, size: 17, color: colors.secondary),
              const SizedBox(width: 9),
              Text(
                AppLocalizations.of(context).newChat,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.secondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.sending,
    required this.deepStudy,
    required this.onDeepStudyChanged,
    required this.onSubmit,
    required this.onStop,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final bool deepStudy;
  final ValueChanged<bool> onDeepStudyChanged;
  final void Function(String text) onSubmit;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Row(
              children: [
                Tooltip(
                  message: deepStudy
                      ? l10n.deepStudyEnabled
                      : l10n.deepStudyDisabled,
                  child: IconButton.filledTonal(
                    isSelected: deepStudy,
                    selectedIcon: const Icon(Icons.manage_search),
                    icon: const Icon(Icons.search),
                    onPressed:
                        sending ? null : () => onDeepStudyChanged(!deepStudy),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: l10n.askAboutSnippets,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onSubmitted: onSubmit,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: sending ? onStop : () => onSubmit(controller.text),
                  tooltip: sending ? l10n.stopGenerating : null,
                  icon: Icon(sending ? Icons.stop : Icons.arrow_upward),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, this.pending = false});

  final LlmMessage message;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == LlmRole.user;
    final colors = Theme.of(context).colorScheme;
    if (!isUser) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 780),
        margin: const EdgeInsets.symmetric(vertical: 14),
        padding: const EdgeInsets.fromLTRB(18, 4, 8, 4),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: colors.primary, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).appTitle.toUpperCase(),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: colors.primary),
            ),
            const SizedBox(height: 8),
            _AssistantContent(content: message.content, pending: pending),
          ],
        ),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 640),
        margin: const EdgeInsets.symmetric(vertical: 7),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: SelectableText(message.content),
      ),
    );
  }
}

class _AssistantContent extends StatelessWidget {
  const _AssistantContent({required this.content, required this.pending});

  final String content;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (content.isEmpty) {
      return pending
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(l10n.thinking,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            )
          : const Text('…');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MarkdownMessage(data: content),
        Align(
          alignment: Alignment.centerRight,
          child: CopyIconButton(text: content),
        ),
      ],
    );
  }
}
