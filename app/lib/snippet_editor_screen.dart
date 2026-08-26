import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kangoos_core/kangoos_core.dart';

import 'code_highlight.dart';
import 'confirm_dialog.dart';
import 'copy_button.dart';
import 'llm_error.dart';
import 'settings_repository.dart';

class SnippetEditorScreen extends StatefulWidget {
  const SnippetEditorScreen({
    super.key,
    required this.snippets,
    required this.settingsRepository,
    required this.onDone,
    this.snippet,
    this.tagger = const SnippetTagger(),
    this.providerBuilder,
    this.onDirtyChanged,
  });

  final SnippetService snippets;
  final SettingsRepository settingsRepository;
  final VoidCallback onDone;
  final Snippet? snippet;
  final SnippetTagger tagger;

  /// Overridable for tests; defaults to [LlmSettings.buildProvider].
  final LlmProvider Function(LlmSettings settings)? providerBuilder;

  final ValueChanged<bool>? onDirtyChanged;

  @override
  State<SnippetEditorScreen> createState() => _SnippetEditorScreenState();
}

class _SnippetEditorScreenState extends State<SnippetEditorScreen> {
  late final _titleController =
      TextEditingController(text: widget.snippet?.title);
  late final _languageController =
      TextEditingController(text: widget.snippet?.language);
  late final _tagsController = TextEditingController(
      text: (widget.snippet?.tags ?? const []).join(', '));
  late final _contentController = HighlightedCodeController(
    text: widget.snippet?.content,
    language: widget.snippet?.language,
  );

  var _suggestingTags = false;
  var _dirty = false;
  CancelToken? _tagCancelToken;
  String? _titleError;
  String? _contentError;

  bool get _isEditing => widget.snippet != null;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _titleController,
      _languageController,
      _tagsController,
      _contentController,
    ]) {
      controller.addListener(_markDirty);
    }
    _languageController.addListener(_syncEditorLanguage);
  }

  void _syncEditorLanguage() =>
      _contentController.language = _languageController.text.trim();

  void _markDirty() {
    if (_dirty) return;
    _dirty = true;
    widget.onDirtyChanged?.call(true);
  }

  void _markClean() {
    _dirty = false;
    widget.onDirtyChanged?.call(false);
  }

  @override
  void dispose() {
    _tagCancelToken?.cancel();
    widget.onDirtyChanged?.call(false);
    _titleController.dispose();
    _languageController.dispose();
    _tagsController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final title = _titleController.text.trim();
    final content = _contentController.text;
    setState(() {
      _titleError = title.isEmpty ? l10n.snippetTitleRequired : null;
      _contentError = content.isEmpty ? l10n.snippetContentRequired : null;
    });
    if (title.isEmpty || content.isEmpty) return;

    final language = _languageController.text.trim();
    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    final SnippetMutationResult result;
    if (_isEditing) {
      result = (await widget.snippets.update(
          widget.snippet!.id,
          SnippetUpdate(
            title: title,
            content: content,
            language: language.isEmpty ? null : language,
            languageProvided: true,
            tags: tags,
            updatedAt: DateTime.now(),
          )))!;
    } else {
      result = await widget.snippets.create(NewSnippet(
        title: title,
        content: content,
        language: language.isEmpty ? null : language,
        tags: tags,
      ));
    }
    if (result.indexingError != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.semanticSearchFailed('${result.indexingError}')),
      ));
    }

    _markClean();
    if (mounted) widget.onDone();
  }

  Future<void> _close() async {
    if (_dirty) {
      final l10n = AppLocalizations.of(context);
      final discard = await confirmDestructiveAction(
        context: context,
        title: l10n.discardChangesTitle,
        body: l10n.discardChangesBody,
        confirmLabel: l10n.discardChangesConfirm,
      );
      if (!discard) return;
    }
    _markClean();
    widget.onDone();
  }

  Future<void> _suggestTags() async {
    final content = _contentController.text.trim();
    if (content.isEmpty || _suggestingTags) return;

    final cancelToken = CancelToken();
    setState(() {
      _suggestingTags = true;
      _tagCancelToken = cancelToken;
    });
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final settings = await widget.settingsRepository.load();
      if (settings.model.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.setModelFirst)));
        return;
      }
      if (settings.requiresApiKey && settings.apiKey.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.setApiKeyFirst)));
        return;
      }

      final buildProvider = widget.providerBuilder ?? (s) => s.buildProvider();
      final tags = await widget.tagger.suggestTags(
        provider: buildProvider(settings),
        title: _titleController.text.trim(),
        content: content,
        language: _languageController.text.trim(),
        cancelToken: cancelToken,
      );

      if (cancelToken.isCancelled) return;
      if (tags.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.noTagsSuggested)));
        return;
      }
      setState(() => _tagsController.text = tags.join(', '));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(l10n.tagSuggestionFailed(describeLlmError(l10n, e)))));
    } finally {
      if (mounted) {
        setState(() {
          _suggestingTags = false;
          _tagCancelToken = null;
        });
      }
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructiveAction(
      context: context,
      title: l10n.deleteSnippetTitle,
      body: l10n.deleteSnippetBody(widget.snippet!.title),
    );
    if (!confirmed) return;

    await widget.snippets.delete(widget.snippet!.id);
    _markClean();
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _close,
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.commonBack,
        ),
        title: Text(_isEditing ? l10n.editSnippet : l10n.newSnippet),
        actions: [
          IconButton(
            onPressed: () =>
                copyTextToClipboard(context, _contentController.text),
            icon: const Icon(Icons.copy_all_outlined),
            tooltip: l10n.copyToClipboard,
          ),
          if (_isEditing)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.commonDelete,
            ),
          IconButton(
              onPressed: _save,
              icon: const Icon(Icons.check),
              tooltip: l10n.commonSave),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 960,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: l10n.snippetTitle,
                  errorText: _titleError,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _languageController,
                      decoration:
                          InputDecoration(labelText: l10n.snippetLanguage),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _tagsController,
                      decoration: InputDecoration(
                        labelText: l10n.snippetTags,
                        suffixIcon: IconButton(
                          icon: Icon(
                              _suggestingTags ? Icons.stop : Icons.auto_awesome,
                              size: 20),
                          tooltip: _suggestingTags
                              ? l10n.stopGenerating
                              : l10n.suggestTagsViaLlm,
                          onPressed: _suggestingTags
                              ? () => _tagCancelToken?.cancel()
                              : _suggestTags,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: l10n.snippetCode,
                  alignLabelWithHint: true,
                  errorText: _contentError,
                ),
                maxLines: 14,
                style: codeTextStyle(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
