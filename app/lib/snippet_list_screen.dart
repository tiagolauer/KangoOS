import 'package:flutter/material.dart';
import 'package:kangoos_core/kangoos_core.dart';

import 'capture/activity_timeline_screen.dart';
import 'capture/capture_settings_repository.dart';
import 'chat_screen.dart';
import 'settings_repository.dart';
import 'settings_screen.dart';
import 'snippet_editor_screen.dart';

class SnippetListScreen extends StatefulWidget {
  const SnippetListScreen({
    super.key,
    required this.database,
    required this.semanticSearch,
    required this.captureSettingsRepository,
  });

  final KangoosDatabase database;
  final SemanticSearch semanticSearch;
  final CaptureSettingsRepository captureSettingsRepository;

  @override
  State<SnippetListScreen> createState() => _SnippetListScreenState();
}

class _SnippetListScreenState extends State<SnippetListScreen> {
  var _query = '';
  var _semantic = false;

  void _openEditor([Snippet? snippet]) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SnippetEditorScreen(
        database: widget.database,
        semanticSearch: widget.semanticSearch,
        snippet: snippet,
      ),
    ));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KangoOS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'Index snippets for semantic search',
            onPressed: _indexMissing,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Activity',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ActivityTimelineScreen(
                database: widget.database,
                captureSettingsRepository: widget.captureSettingsRepository,
              ),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Chat',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChatScreen(
                database: widget.database,
                semanticSearch: widget.semanticSearch,
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
              decoration: InputDecoration(
                hintText: _semantic ? 'Search snippets (semantic)' : 'Search snippets',
                prefixIcon: IconButton(
                  icon: Icon(_semantic ? Icons.auto_awesome : Icons.search),
                  tooltip: _semantic ? 'Switch to keyword search' : 'Switch to semantic search',
                  onPressed: () => setState(() => _semantic = !_semantic),
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_query.isEmpty) {
      return StreamBuilder<List<Snippet>>(
        stream: widget.database.watchAllSnippets(),
        builder: (context, snapshot) =>
            _SnippetListView(snippets: snapshot.data, onTap: _openEditor),
      );
    }
    if (_semantic) {
      return FutureBuilder<List<SemanticMatch>>(
        future: widget.semanticSearch.search(_query),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _SearchErrorView(error: snapshot.error!);
          }
          final snippets = snapshot.data?.map((match) => match.snippet).toList();
          return _SnippetListView(snippets: snippets, onTap: _openEditor);
        },
      );
    }
    return FutureBuilder<List<Snippet>>(
      future: widget.database.searchByKeyword(_query),
      builder: (context, snapshot) =>
          _SnippetListView(snippets: snapshot.data, onTap: _openEditor),
    );
  }
}

class _SearchErrorView extends StatelessWidget {
  const _SearchErrorView({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Semantic search failed: $error\n\nMake sure Ollama is running with '
          'the embedding model pulled.',
          textAlign: TextAlign.center,
        ),
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
