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
import '../settings_repository.dart';
import '../settings_screen.dart';
import '../sync/sync_settings_repository.dart';
import '../sync/sync_settings_screen.dart';
import '../theme/kangoos_theme.dart';
import 'activity_sparkline.dart';

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
    required this.database,
    required this.semanticSearch,
    required this.settingsRepository,
    required this.captureSettingsRepository,
    this.providerBuilder,
  });

  final KangoosDatabase database;
  final SemanticSearch semanticSearch;
  final SettingsRepository settingsRepository;
  final CaptureSettingsRepository captureSettingsRepository;

  /// Overridable for tests; defaults to [LlmSettings.buildProvider].
  final LlmProvider Function(LlmSettings settings)? providerBuilder;

  @override
  State<ChatHomePanel> createState() => _ChatHomePanelState();
}

class _ChatHomePanelState extends State<ChatHomePanel> {
  late final _ragChat = RagChat(
    database: widget.database,
    semanticSearch: widget.semanticSearch,
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
    final id = await widget.database.latestConversationId();
    if (id == null || !mounted) return;
    final messages = await widget.database.messagesForConversation(id);
    if (!mounted) return;
    setState(() {
      _conversationId = id;
      _history
        ..clear()
        ..addAll(messages
            .map((m) => LlmMessage(role: m.role, content: m.content)));
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
    final messages = await widget.database.messagesForConversation(id);
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
        database: widget.database,
        currentConversationId: _conversationId,
      ),
    );
    if (selectedId != null) await _loadConversationById(selectedId);
    if (_conversationId != null &&
        (await widget.database.messagesForConversation(_conversationId!))
            .isEmpty &&
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
      final count = await widget.semanticSearch.indexMissing();
      messenger
          .showSnackBar(SnackBar(content: Text(l10n.indexedSnippets(count))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.indexingFailed('$e'))));
    }
  }

  Future<void> _exportSnippets() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final exchange = SnippetExchange(database: widget.database);
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
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.snippetsExported)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.exportFailed('$e'))));
    }
  }

  Future<void> _importSnippets() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final exchange = SnippetExchange(
      database: widget.database,
      semanticSearch: widget.semanticSearch,
    );
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON', extensions: ['json'])
        ],
      );
      if (file == null) return;
      final result = await exchange.importJson(await file.readAsString());
      messenger.showSnackBar(SnackBar(
          content: Text(l10n.importSucceeded(result.imported, result.skipped))));
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
    if (settings.provider != LlmProviderKind.ollama &&
        settings.apiKey.isEmpty) {
      setState(() => _error = l10n.setApiKeyFirst);
      return;
    }

    final priorHistory = List<LlmMessage>.of(_history);
    _conversationId ??= await widget.database.createConversation();
    final userMessageId = await widget.database
        .appendMessage(_conversationId!, LlmRole.user, trimmed);

    setState(() {
      _error = null;
      _history.add(LlmMessage(role: LlmRole.user, content: trimmed));
      _history.add(const LlmMessage(role: LlmRole.assistant, content: ''));
      _inputController.clear();
      _sending = true;
    });
    _scrollToEnd();

    final buildProvider = widget.providerBuilder ?? (s) => s.buildProvider();
    final provider = buildProvider(settings);

    final buffer = StringBuffer();
    try {
      await for (final chunk in _ragChat.reply(
        provider: provider,
        history: priorHistory,
        userMessage: trimmed,
      )) {
        buffer.write(chunk);
        setState(() {
          _history[_history.length - 1] =
              LlmMessage(role: LlmRole.assistant, content: buffer.toString());
        });
        _scrollToEnd();
      }
    } catch (e) {
      setState(() => _error = l10n.chatRequestFailed('$e'));
    } finally {
      await _persistReply(userMessageId, buffer.toString(), trimmed);
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _persistReply(
      int userMessageId, String reply, String userMessage) async {
    if (reply.isNotEmpty) {
      await widget.database
          .appendMessage(_conversationId!, LlmRole.assistant, reply);
      return;
    }

    await widget.database.deleteMessage(userMessageId);
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
          showNewChat: _started,
          onNewChat: _startNewChat,
          onOpenHistory: _openHistory,
          onIndexMissing: _indexMissing,
          onOpenCaptureSettings: () async {
            await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CaptureSettingsScreen(
                repository: widget.captureSettingsRepository,
                database: widget.database,
              ),
            ));
            _loadCaptureState();
          },
          onOpenLlmSettings: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                SettingsScreen(repository: widget.settingsRepository),
          )),
          onOpenSyncSettings: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SyncSettingsScreen(
              repository: _syncSettingsRepository,
              database: widget.database,
              semanticSearch: widget.semanticSearch,
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
                        color: Theme.of(context)
                            .colorScheme
                            .onTertiaryContainer),
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
          onSubmit: _send,
        ),
      ],
    );
  }

  Widget _buildGreeting(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final summaryActions = _summaryActionsFor(l10n);
    final suggestions =
        _freeformSuggestions ?? _freeformPoolFor(l10n).take(2).toList();
    final userName = _osUserName();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            userName == null ? l10n.greeting : l10n.greetingNamed(userName),
            style: textTheme.headlineLarge,
          ),
          const SizedBox(height: 24),
          Text(l10n.sectionSingleClickSummaries, style: textTheme.labelSmall),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 700 ? 3 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 132,
                ),
                itemCount: summaryActions.length,
                itemBuilder: (context, index) => _SummaryActionCard(
                    action: summaryActions[index], onTap: _send),
              );
            },
          ),
          const SizedBox(height: 28),
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
          const SizedBox(height: 4),
          StreamBuilder<List<Snippet>>(
            stream: widget.database.watchAllSnippets(),
            builder: (context, snapshot) {
              final snippets = snapshot.data;
              final mostRecent = (snippets != null && snippets.isNotEmpty)
                  ? snippets.first
                  : null;
              final chips = [
                if (mostRecent != null) l10n.explainSnippet(mostRecent.title),
                ...suggestions,
              ];
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final suggestion in chips)
                    _FreeformChip(
                        text: suggestion, onTap: () => _send(suggestion)),
                  _StartNewChatChip(
                      onTap: () => _inputFocusNode.requestFocus()),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Text("TODAY'S ACTIVITY", style: textTheme.labelSmall),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final now = DateTime.now();
            final startOfDay = DateTime(now.year, now.month, now.day);
            return StreamBuilder<List<Activity>>(
              stream: widget.database.watchActivitiesBetween(
                  startOfDay, startOfDay.add(const Duration(days: 1))),
              builder: (context, snapshot) {
                final hourly =
                    bucketActivityMinutesByHour(snapshot.data ?? const []);
                return ActivitySparkline(
                    hourlyMinutes: hourly, isCapturing: _capturing);
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildConversation(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) => _ChatBubble(message: _history[index]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.showNewChat,
    required this.onNewChat,
    required this.onOpenHistory,
    required this.onIndexMissing,
    required this.onOpenCaptureSettings,
    required this.onOpenLlmSettings,
    required this.onOpenSyncSettings,
    required this.onExportSnippets,
    required this.onImportSnippets,
  });

  final bool showNewChat;
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.outline))),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: colors.primary),
          const SizedBox(width: 8),
          Text(l10n.appTitle, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (showNewChat)
            IconButton(
              icon: const Icon(Icons.add_comment_outlined),
              tooltip: l10n.newChat,
              onPressed: onNewChat,
            ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: l10n.chatHistory,
            onPressed: onOpenHistory,
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: l10n.indexSnippets,
            onPressed: onIndexMissing,
          ),
          IconButton(
            icon: const Icon(Icons.privacy_tip_outlined),
            tooltip: l10n.captureSettings,
            onPressed: onOpenCaptureSettings,
          ),
          IconButton(
            icon: const Icon(Icons.sync_outlined),
            tooltip: l10n.serverSync,
            onPressed: onOpenSyncSettings,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.llmSettings,
            onPressed: onOpenLlmSettings,
          ),
          PopupMenuButton<void>(
            tooltip: l10n.more,
            itemBuilder: (context) => [
              PopupMenuItem<void>(
                onTap: onExportSnippets,
                child: ListTile(
                  leading: Icon(Icons.upload_file_outlined),
                  title: Text(l10n.exportSnippets),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<void>(
                onTap: onImportSnippets,
                child: ListTile(
                  leading: Icon(Icons.download_outlined),
                  title: Text(l10n.importSnippets),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ConversationHistorySheet extends StatelessWidget {
  const ConversationHistorySheet({
    super.key,
    required this.database,
    required this.currentConversationId,
  });

  final KangoosDatabase database;
  final int? currentConversationId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6),
        child: StreamBuilder<List<ConversationSummary>>(
          stream: database.watchConversationSummaries(),
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
                        await database.deleteConversation(conversation.id);
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
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(action.prompt),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(action.icon, color: accent, size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                action.title,
                style:
                    textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                action.description,
                style: textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
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
      color: colors.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, size: 15, color: colors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.onSurface),
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
      color: colors.primaryContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 15, color: colors.onPrimaryContainer),
              const SizedBox(width: 8),
              Text(
                'Start new chat',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w600),
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
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool sending;
  final void Function(String text) onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).askAboutSnippets),
                onSubmitted: onSubmit,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: sending ? null : () => onSubmit(controller.text),
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final LlmMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == LlmRole.user;
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              isUser ? colors.primaryContainer : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message.content.isEmpty ? '…' : message.content),
      ),
    );
  }
}
