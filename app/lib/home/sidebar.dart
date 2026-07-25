import 'package:flutter/material.dart';
import 'package:kangoos_core/kangoos_core.dart';

import 'relative_time.dart';

enum SidebarTab { snippets, activity }

class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    required this.database,
    required this.semanticSearch,
    required this.onSelectSnippet,
    required this.onCreateSnippet,
  });

  final KangoosDatabase database;
  final SemanticSearch semanticSearch;
  final void Function(Snippet snippet) onSelectSnippet;
  final VoidCallback onCreateSnippet;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  var _tab = SidebarTab.snippets;
  var _query = '';
  var _semantic = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        border: Border(right: BorderSide(color: colors.outline)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<SidebarTab>(
                    segments: const [
                      ButtonSegment(value: SidebarTab.snippets, label: Text('Snippets')),
                      ButtonSegment(value: SidebarTab.activity, label: Text('Activity')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (selection) => setState(() => _tab = selection.first),
                    showSelectedIcon: false,
                  ),
                ),
                if (_tab == SidebarTab.snippets) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: widget.onCreateSnippet,
                    icon: const Icon(Icons.add),
                    tooltip: 'New snippet',
                  ),
                ],
              ],
            ),
          ),
          if (_tab == SidebarTab.snippets)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                decoration: InputDecoration(
                  isDense: true,
                  hintText: _semantic ? 'Filter snippets (semantic)' : 'Filter snippets',
                  prefixIcon: IconButton(
                    icon: Icon(_semantic ? Icons.auto_awesome : Icons.search, size: 18),
                    tooltip: _semantic ? 'Switch to keyword search' : 'Switch to semantic search',
                    onPressed: () => setState(() => _semantic = !_semantic),
                  ),
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
          Expanded(
            child: _tab == SidebarTab.snippets ? _buildSnippets(context) : _buildActivity(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSnippets(BuildContext context) {
    if (_query.isEmpty) {
      return StreamBuilder<List<Snippet>>(
        stream: widget.database.watchAllSnippets(),
        builder: (context, snapshot) => _SnippetList(
          snippets: snapshot.data,
          onTap: widget.onSelectSnippet,
        ),
      );
    }
    if (_semantic) {
      return FutureBuilder<List<SemanticMatch>>(
        future: widget.semanticSearch.search(_query),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _SidebarMessage(text: 'Semantic search failed: ${snapshot.error}');
          }
          return _SnippetList(
            snippets: snapshot.data?.map((match) => match.snippet).toList(),
            onTap: widget.onSelectSnippet,
          );
        },
      );
    }
    return FutureBuilder<List<Snippet>>(
      future: widget.database.searchByKeyword(_query),
      builder: (context, snapshot) => _SnippetList(
        snippets: snapshot.data,
        onTap: widget.onSelectSnippet,
      ),
    );
  }

  Widget _buildActivity(BuildContext context) {
    return StreamBuilder<List<Activity>>(
      stream: widget.database.watchRecentActivities(),
      builder: (context, snapshot) {
        final activities = snapshot.data;
        if (activities == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (activities.isEmpty) {
          return const _SidebarMessage(text: 'No activity captured yet.');
        }
        return ListView.builder(
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final activity = activities[index];
            return ListTile(
              dense: true,
              title: Text(
                activity.windowTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(activity.appName, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(
                formatClockTime(activity.capturedAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          },
        );
      },
    );
  }
}

class _SidebarMessage extends StatelessWidget {
  const _SidebarMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _SnippetList extends StatelessWidget {
  const _SnippetList({required this.snippets, required this.onTap});

  final List<Snippet>? snippets;
  final void Function(Snippet snippet) onTap;

  @override
  Widget build(BuildContext context) {
    if (snippets == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snippets!.isEmpty) {
      return const _SidebarMessage(text: 'No snippets yet. Tap + to add one.');
    }
    final textTheme = Theme.of(context).textTheme;
    return ListView.builder(
      itemCount: snippets!.length,
      itemBuilder: (context, index) {
        final snippet = snippets![index];
        return InkWell(
          onTap: () => onTap(snippet),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snippet.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (snippet.language != null && snippet.language!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(snippet.language!, style: textTheme.labelSmall),
                  ),
                const SizedBox(height: 4),
                Text(
                  snippet.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(formatRelativeTime(snippet.updatedAt), style: textTheme.labelSmall),
              ],
            ),
          ),
        );
      },
    );
  }
}
