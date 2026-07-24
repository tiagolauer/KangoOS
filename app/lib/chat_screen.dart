import 'package:flutter/material.dart';
import 'package:kangoos_core/kangoos_core.dart';

import 'settings_repository.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.database,
    required this.settingsRepository,
    this.providerBuilder,
  });

  final KangoosDatabase database;
  final SettingsRepository settingsRepository;

  /// Overridable for tests; defaults to [LlmSettings.buildProvider].
  final LlmProvider Function(LlmSettings settings)? providerBuilder;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _maxContextSnippets = 5;

  final _history = <LlmMessage>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  var _sending = false;
  String? _error;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<Snippet>> _retrieveContext(String query) async {
    final matches = await widget.database.searchByKeyword(query);
    return matches.take(_maxContextSnippets).toList();
  }

  String _buildSystemPrompt(List<Snippet> context) {
    final buffer = StringBuffer(
      'You are the KangoOS assistant. Answer using the snippets below when '
      'relevant. If none are relevant, say so and answer generally.',
    );
    for (final snippet in context) {
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln('Title: ${snippet.title}');
      if (snippet.language != null && snippet.language!.isNotEmpty) {
        buffer.writeln('Language: ${snippet.language}');
      }
      buffer.writeln(snippet.content);
    }
    return buffer.toString();
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;

    final settings = await widget.settingsRepository.load();
    if (settings.model.isEmpty) {
      setState(() => _error = 'Set a model in LLM settings first.');
      return;
    }
    if (settings.provider != LlmProviderKind.ollama && settings.apiKey.isEmpty) {
      setState(() => _error = 'Set an API key in LLM settings first.');
      return;
    }

    setState(() {
      _error = null;
      _history.add(LlmMessage(role: LlmRole.user, content: text));
      _history.add(const LlmMessage(role: LlmRole.assistant, content: ''));
      _inputController.clear();
      _sending = true;
    });
    _scrollToEnd();

    final context = await _retrieveContext(text);
    final buildProvider = widget.providerBuilder ?? (s) => s.buildProvider();
    final provider = buildProvider(settings);
    final requestMessages = [
      LlmMessage(role: LlmRole.system, content: _buildSystemPrompt(context)),
      ..._history.sublist(0, _history.length - 1),
    ];

    final buffer = StringBuffer();
    try {
      await for (final chunk in provider.chat(requestMessages)) {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
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
          Expanded(
            child: _history.isEmpty
                ? const Center(child: Text('Ask something about your snippets.'))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _history.length,
                    itemBuilder: (context, index) => _ChatBubble(message: _history[index]),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        hintText: 'Ask about your snippets',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message.content.isEmpty ? '…' : message.content),
      ),
    );
  }
}
