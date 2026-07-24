import 'package:flutter/material.dart';
import 'package:kangoos_core/kangoos_core.dart';

import 'chat_screen.dart';
import 'settings_repository.dart';
import 'settings_screen.dart';
import 'snippet_editor_screen.dart';

class SnippetListScreen extends StatefulWidget {
  const SnippetListScreen({super.key, required this.database});

  final KangoosDatabase database;

  @override
  State<SnippetListScreen> createState() => _SnippetListScreenState();
}

class _SnippetListScreenState extends State<SnippetListScreen> {
  var _query = '';

  void _openEditor([Snippet? snippet]) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SnippetEditorScreen(database: widget.database, snippet: snippet),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KangoOS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Chat',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChatScreen(
                database: widget.database,
                settingsRepository: SettingsRepository(),
              ),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'LLM settings',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SettingsScreen(repository: SettingsRepository()),
            )),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search snippets',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
        ),
      ),
      body: _query.isEmpty
          ? StreamBuilder<List<Snippet>>(
              stream: widget.database.watchAllSnippets(),
              builder: (context, snapshot) => _SnippetListView(
                snippets: snapshot.data,
                onTap: _openEditor,
              ),
            )
          : FutureBuilder<List<Snippet>>(
              future: widget.database.searchByKeyword(_query),
              builder: (context, snapshot) => _SnippetListView(
                snippets: snapshot.data,
                onTap: _openEditor,
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SnippetListView extends StatelessWidget {
  const _SnippetListView({required this.snippets, required this.onTap});

  final List<Snippet>? snippets;
  final void Function(Snippet snippet) onTap;

  @override
  Widget build(BuildContext context) {
    if (snippets == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snippets!.isEmpty) {
      return const Center(child: Text('No snippets yet. Tap + to add one.'));
    }
    return ListView.separated(
      itemCount: snippets!.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final snippet = snippets![index];
        return ListTile(
          title: Text(snippet.title),
          subtitle: Text(
            snippet.content,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: snippet.language == null || snippet.language!.isEmpty
              ? null
              : Chip(label: Text(snippet.language!)),
          onTap: () => onTap(snippet),
        );
      },
    );
  }
}
