import 'package:flutter/material.dart';
import 'package:kangoos_core/kangoos_core.dart';

import '../capture/capture_settings_repository.dart';
import '../capture/capture_settings_screen.dart';
import '../settings_repository.dart';
import '../settings_screen.dart';
import 'activity_sparkline.dart';

class _QuickAction {
  const _QuickAction({required this.icon, required this.title, required this.description, required this.prompt});

  final IconData icon;
  final String title;
  final String description;
  final String prompt;
}

const _quickActions = [
  _QuickAction(
    icon: Icons.wb_sunny_outlined,
    title: 'What did I work on today?',
    description: "Summary from today's captured activity",
    prompt: 'Summarize what I worked on today based on my captured activity.',
  ),
  _QuickAction(
    icon: Icons.code_outlined,
    title: 'Recent snippets',
    description: 'Overview of what you last saved',
    prompt: 'Summarize my most recently saved snippets.',
  ),
  _QuickAction(
    icon: Icons.sell_outlined,
    title: 'Missing tags',
    description: 'Find snippets that need tagging',
    prompt: 'Which of my snippets are missing a language or tags? Suggest some.',
  ),
  _QuickAction(
    icon: Icons.insights_outlined,
    title: 'Spot a pattern',
    description: 'Themes across your snippets',
    prompt: 'Look at my snippets and tell me what patterns or themes stand out.',
  ),
];

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
  late final _ragChat = RagChat(database: widget.database, semanticSearch: widget.semanticSearch);

  final _history = <LlmMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  var _sending = false;
  String? _error;

  bool get _started => _history.isNotEmpty;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _indexMissing() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await widget.semanticSearch.indexMissing();
      messenger.showSnackBar(SnackBar(content: Text('Indexed $count snippet(s).')));
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
    if (settings.provider != LlmProviderKind.ollama && settings.apiKey.isEmpty) {
      setState(() => _error = 'Set an API key in LLM settings first.');
      return;
    }

    final priorHistory = List<LlmMessage>.of(_history);

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
          onIndexMissing: _indexMissing,
          onOpenCaptureSettings: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CaptureSettingsScreen(repository: widget.captureSettingsRepository),
          )),
          onOpenLlmSettings: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SettingsScreen(repository: widget.settingsRepository),
          )),
        ),
        if (_error != null)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.errorContainer,
            padding: const EdgeInsets.all(8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
            ),
          ),
        Expanded(child: _started ? _buildConversation(context) : _buildGreeting(context)),
        _Composer(controller: _inputController, sending: _sending, onSubmit: _send),
      ],
    );
  }

  Widget _buildGreeting(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How can I help today?', style: textTheme.headlineLarge),
          const SizedBox(height: 24),
          Text('QUICK ACTIONS', style: textTheme.labelSmall),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 88,
            ),
            itemCount: _quickActions.length,
            itemBuilder: (context, index) =>
                _QuickActionCard(action: _quickActions[index], onTap: _send),
          ),
          const SizedBox(height: 28),
          Text("TODAY'S ACTIVITY", style: textTheme.labelSmall),
          const SizedBox(height: 8),
          StreamBuilder<List<Activity>>(
            stream: widget.database.watchRecentActivities(limit: 500),
            builder: (context, snapshot) {
              final hourly = bucketActivityByHour(snapshot.data ?? const []);
              return ActivitySparkline(hourlyCounts: hourly);
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
    required this.onIndexMissing,
    required this.onOpenCaptureSettings,
    required this.onOpenLlmSettings,
  });

  final VoidCallback onIndexMissing;
  final VoidCallback onOpenCaptureSettings;
  final VoidCallback onOpenLlmSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.outline))),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: colors.primary),
          const SizedBox(width: 8),
          Text('KangoOS', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
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

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action, required this.onTap});

  final _QuickAction action;
  final void Function(String prompt) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(action.prompt),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(action.icon, color: colors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.onSubmit});

  final TextEditingController controller;
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
                decoration: const InputDecoration(hintText: 'Ask about your snippets or activity'),
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
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isUser ? colors.primaryContainer : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message.content.isEmpty ? '…' : message.content),
      ),
    );
  }
}
