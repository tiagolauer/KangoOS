import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:kangoos_core/kangoos_core.dart';

class SnippetEditorScreen extends StatefulWidget {
  const SnippetEditorScreen({super.key, required this.database, this.snippet});

  final KangoosDatabase database;
  final Snippet? snippet;

  @override
  State<SnippetEditorScreen> createState() => _SnippetEditorScreenState();
}

class _SnippetEditorScreenState extends State<SnippetEditorScreen> {
  late final _titleController = TextEditingController(text: widget.snippet?.title);
  late final _languageController = TextEditingController(text: widget.snippet?.language);
  late final _tagsController =
      TextEditingController(text: (widget.snippet?.tags ?? const []).join(', '));
  late final _contentController = TextEditingController(text: widget.snippet?.content);

  bool get _isEditing => widget.snippet != null;

  @override
  void dispose() {
    _titleController.dispose();
    _languageController.dispose();
    _tagsController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text;
    if (title.isEmpty || content.isEmpty) return;

    final language = _languageController.text.trim();
    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    if (_isEditing) {
      await widget.database.updateSnippet(widget.snippet!.copyWith(
        title: title,
        content: content,
        language: Value(language.isEmpty ? null : language),
        tags: tags,
        updatedAt: DateTime.now(),
      ));
    } else {
      await widget.database.createSnippet(SnippetsCompanion.insert(
        title: title,
        content: content,
        language: Value(language.isEmpty ? null : language),
        tags: Value(tags),
      ));
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    await widget.database.deleteSnippet(widget.snippet!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit snippet' : 'New snippet'),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
            ),
          IconButton(onPressed: _save, icon: const Icon(Icons.check), tooltip: 'Save'),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _languageController,
                    decoration: const InputDecoration(labelText: 'Language (optional)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _tagsController,
                    decoration: const InputDecoration(labelText: 'Tags (comma-separated)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Code',
                alignLabelWithHint: true,
              ),
              maxLines: 14,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}
