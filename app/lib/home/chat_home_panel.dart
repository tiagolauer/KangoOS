import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kangoos_core/kangoos_core.dart';

import '../capture/capture_settings_repository.dart';
import '../capture/capture_settings_screen.dart';
import '../settings_repository.dart';
import '../settings_screen.dart';
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

const _summaryActions = [
  _SummaryAction(
    icon: Icons.wb_sunny_outlined,
    title: 'Day recap',
    description: "Summary of today's captured activity",
    prompt: 'Summarize what I worked on today based on my captured activity.',
    accent: _AccentRole.primary,
  ),
  _SummaryAction(
    icon: Icons.forum_outlined,
    title: 'Standup update',
    description: "What you did, what's next, any blockers",
    prompt: "Give me a standup update: what I worked on, what's next, and any "
        'blockers, based on my captured activity and snippets.',
    accent: _AccentRole.later,
  ),
  _SummaryAction(
    icon: Icons.code_outlined,
    title: 'Recent snippets',
    description: 'Overview of what you last saved',
    prompt: 'Summarize my most recently saved snippets.',
    accent: _AccentRole.done,
  ),
  _SummaryAction(
    icon: Icons.sell_outlined,
    title: 'Missing tags',
    description: 'Find snippets that need tagging',
    prompt:
        'Which of my snippets are missing a language or tags? Suggest some.',
    accent: _AccentRole.next,
  ),
  _SummaryAction(
    icon: Icons.insights_outlined,
    title: "What's top of mind",
    description: 'Recurring themes across your snippets',
    prompt:
        'Look at my snippets and tell me what themes or topics come up most.',
    accent: _AccentRole.done,
  ),
  _SummaryAction(
    icon: Icons.schedule_outlined,
    title: 'Time breakdown',
    description: 'Where your time went today, by app',
    prompt: 'Break down how I spent my time today by app or activity, based on '
        'my captured activity.',
    accent: _AccentRole.primary,
  ),
];

const _freeformPool = [
  'Summarize my snippets from this week',
  'What languages do I use most often?',
  'Which snippets have I not touched in a while?',
  'Draft a commit message for my latest change',
  'What should I clean up or refactor next?',
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
  late final _ragChat =
      RagChat(database: widget.database, semanticSearch: widget.semanticSearch);

  final _history = <LlmMessage>[];
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _random = Random();
  var _sending = false;
  var _capturing = true;
  int? _conversationId;
  String? _error;
  List<String> _freeformSuggestions = _freeformPool.take(2).toList();

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

  void _shuffleFreeformSuggestions() {
    setState(() {
      final pool = List<String>.of(_freeformPool)..shuffle(_random);
      _freeformSuggestions = pool.take(2).toList();
    });
  }

  Future<void> _indexMissing() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await widget.semanticSearch.indexMissing();
      messenger
          .showSnackBar(SnackBar(content: Text('Indexed $count snippet(s).')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Indexing failed: $e')));
    }
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;

    final settings = await widget.settingsRepository.load();
    if (settings.model.isEmpty) {
      setState(() => _error = 'Set a model in LLM settings first.');
      return;
    }
    if (settings.provider != LlmProviderKind.ollama &&
        settings.apiKey.isEmpty) {
      setState(() => _error = 'Set an API key in LLM settings first.');
      return;
    }

    final priorHistory = List<LlmMessage>.of(_history);
    _conversationId ??= await widget.database.createConversation();
    await widget.database.appendMessage(_conversationId!, LlmRole.user, trimmed);

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
      if (buffer.isNotEmpty) {
        await widget.database
            .appendMessage(_conversationId!, LlmRole.assistant, buffer.toString());
      }
    } catch (e) {
      setState(() => _error = 'Request failed: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
    return Column(
      children: [
        _Header(
          showNewChat: _started,
          onNewChat: _startNewChat,
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
    final userName = _osUserName();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            userName == null
                ? 'How can I help today?'
                : 'How can I help today, $userName?',
            style: textTheme.headlineLarge,
          ),
          const SizedBox(height: 24),
          Text('SINGLE-CLICK SUMMARIES', style: textTheme.labelSmall),
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
                itemCount: _summaryActions.length,
                itemBuilder: (context, index) => _SummaryActionCard(
                    action: _summaryActions[index], onTap: _send),
              );
            },
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Text('FREEFORM CHAT', style: textTheme.labelSmall),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Shuffle suggestions',
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
              final suggestions = [
                if (mostRecent != null) 'Explain "${mostRecent.title}"',
                ..._freeformSuggestions,
              ];
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final suggestion in suggestions)
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
          StreamBuilder<List<Activity>>(
            stream: widget.database.watchRecentActivities(limit: 500),
            builder: (context, snapshot) {
              final hourly = bucketActivityByHour(snapshot.data ?? const []);
              return ActivitySparkline(
                  hourlyCounts: hourly, isCapturing: _capturing);
            },
          ),
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
    required this.onIndexMissing,
    required this.onOpenCaptureSettings,
    required this.onOpenLlmSettings,
  });

  final bool showNewChat;
  final VoidCallback onNewChat;
  final VoidCallback onIndexMissing;
  final VoidCallback onOpenCaptureSettings;
  final VoidCallback onOpenLlmSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.outline))),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: colors.primary),
          const SizedBox(width: 8),
          Text('KangoOS', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (showNewChat)
            IconButton(
              icon: const Icon(Icons.add_comment_outlined),
              tooltip: 'New chat',
              onPressed: onNewChat,
            ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'Index snippets for semantic search',
            onPressed: onIndexMissing,
          ),
          IconButton(
            icon: const Icon(Icons.privacy_tip_outlined),
            tooltip: 'Activity capture settings',
            onPressed: onOpenCaptureSettings,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'LLM settings',
            onPressed: onOpenLlmSettings,
          ),
        ],
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
                decoration: const InputDecoration(
                    hintText: 'Ask about your snippets or activity'),
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
