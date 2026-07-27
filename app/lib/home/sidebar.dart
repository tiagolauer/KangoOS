import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kangoos_core/kangoos_core.dart';

import '../copy_button.dart';
import 'relative_time.dart';

enum SidebarTab { snippets, activity, timeline }

class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    required this.database,
    required this.semanticSearch,
    required this.onSelectSnippet,
    required this.onCreateSnippet,
    required this.onGenerateDayRecap,
  });

  final KangoosDatabase database;
  final SemanticSearch semanticSearch;
  final void Function(Snippet snippet) onSelectSnippet;
  final VoidCallback onCreateSnippet;
  final Future<SummaryResult> Function(CancelToken cancelToken)
      onGenerateDayRecap;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  static const _searchDebounce = Duration(milliseconds: 280);

  var _tab = SidebarTab.snippets;
  var _query = '';
  var _semantic = false;
  var _generatingRecap = false;
  Timer? _searchDebounceTimer;
  Future<List<Snippet>>? _search;
  CancelToken? _recapCancelToken;

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _recapCancelToken?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer =
        Timer(_searchDebounce, () => _applyQuery(value.trim()));
  }

  void _applyQuery(String query) {
    if (query == _query || !mounted) return;
    setState(() {
      _query = query;
      _search = query.isEmpty ? null : _runSearch(query);
    });
  }

  void _toggleSemantic() {
    setState(() {
      _semantic = !_semantic;
      _search = _query.isEmpty ? null : _runSearch(_query);
    });
  }

  Future<List<Snippet>> _runSearch(String query) async {
    if (!_semantic) return widget.database.searchByKeyword(query);
    final matches = await widget.semanticSearch.search(query);
    return matches.map((match) => match.snippet).toList();
  }

  Future<void> _generateDayRecap() async {
    if (_generatingRecap) return;
    final cancelToken = CancelToken();
    setState(() {
      _generatingRecap = true;
      _recapCancelToken = cancelToken;
    });
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final result = await widget.onGenerateDayRecap(cancelToken);
      final message = switch (result) {
        SummarySuccess() => l10n.dayRecapGenerated,
        SummaryFailure(error: SummaryError.noActivity) =>
          l10n.dayRecapNoActivity,
        SummaryFailure(error: SummaryError.llmFailed) =>
          l10n.dayRecapLlmFailed,
        SummaryFailure(error: SummaryError.cancelled) => l10n.dayRecapCancelled,
      };
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _generatingRecap = false;
          _recapCancelToken = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
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
                    segments: [
                      ButtonSegment(
                          value: SidebarTab.snippets, label: Text(l10n.tabSnippets)),
                      ButtonSegment(
                          value: SidebarTab.activity, label: Text(l10n.tabActivity)),
                      ButtonSegment(
                          value: SidebarTab.timeline, label: Text(l10n.tabTimeline)),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (selection) =>
                        setState(() => _tab = selection.first),
                    showSelectedIcon: false,
                  ),
                ),
                if (_tab == SidebarTab.snippets) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: widget.onCreateSnippet,
                    icon: const Icon(Icons.add),
                    tooltip: l10n.newSnippet,
                  ),
                ],
                if (_tab == SidebarTab.timeline) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _generatingRecap
                        ? () => _recapCancelToken?.cancel()
                        : _generateDayRecap,
                    icon: Icon(
                        _generatingRecap ? Icons.stop : Icons.auto_awesome),
                    tooltip: _generatingRecap
                        ? l10n.stopGenerating
                        : l10n.generateDayRecap,
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
                  hintText: _semantic
                      ? l10n.filterSnippetsSemantic
                      : l10n.filterSnippets,
                  prefixIcon: IconButton(
                    icon: Icon(_semantic ? Icons.auto_awesome : Icons.search,
                        size: 18),
                    tooltip: _semantic
                        ? l10n.switchToKeywordSearch
                        : l10n.switchToSemanticSearch,
                    onPressed: _toggleSemantic,
                  ),
                ),
                onChanged: _onQueryChanged,
              ),
            ),
          Expanded(
            child: switch (_tab) {
              SidebarTab.snippets => _buildSnippets(context),
              SidebarTab.activity => _buildActivity(context),
              SidebarTab.timeline => _buildTimeline(context),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSnippets(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final search = _search;
    if (search == null) {
      return StreamBuilder<List<Snippet>>(
        stream: widget.database.watchAllSnippets(),
        builder: (context, snapshot) => _SnippetList(
          snippets: snapshot.data,
          onTap: widget.onSelectSnippet,
        ),
      );
    }
    return FutureBuilder<List<Snippet>>(
      future: search,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _SidebarMessage(
            text: _semantic
                ? l10n.semanticSearchFailed('${snapshot.error}')
                : '${snapshot.error}',
          );
        }
        return _SnippetList(
          snippets: snapshot.data,
          onTap: widget.onSelectSnippet,
        );
      },
    );
  }

  Widget _buildActivity(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<List<Activity>>(
      stream: widget.database.watchRecentActivities(),
      builder: (context, snapshot) {
        final activities = snapshot.data;
        if (activities == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (activities.isEmpty) {
          return _SidebarMessage(text: l10n.noActivityYet);
        }
        final rows = groupByDay(activities, (a) => a.capturedAt);
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            if (row is DateTime) return _DayHeader(day: row);
            final activity = row as Activity;
            return Dismissible(
              key: ValueKey(activity.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Theme.of(context).colorScheme.errorContainer,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer),
              ),
              onDismissed: (_) => _deleteActivityWithUndo(context, activity),
              child: ListTile(
                dense: true,
                title: Text(
                  activity.windowTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(activity.appName,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text(
                  formatClockTime(l10n, activity.capturedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteActivityWithUndo(
      BuildContext context, Activity activity) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await widget.database.deleteActivity(activity.id);

    messenger.showSnackBar(SnackBar(
      content: Text(l10n.activityDeleted),
      action: SnackBarAction(
        label: l10n.commonUndo,
        onPressed: () => widget.database.logActivity(
          ActivitiesCompanion.insert(
            appName: activity.appName,
            windowTitle: activity.windowTitle,
            capturedText: Value(activity.capturedText),
            capturedUrl: Value(activity.capturedUrl),
            capturedClipboard: Value(activity.capturedClipboard),
            capturedScreenText: Value(activity.capturedScreenText),
            capturedAudioText: Value(activity.capturedAudioText),
            capturedAt: Value(activity.capturedAt),
          ),
        ),
      ),
    ));
  }

  Widget _buildTimeline(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<List<ActivitySummary>>(
      stream: widget.database.watchRecentSummaries(),
      builder: (context, snapshot) {
        final summaries = snapshot.data;
        if (summaries == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (summaries.isEmpty) {
          return _SidebarMessage(text: l10n.noSummariesYet);
        }
        final rows = groupByDay(summaries, (s) => s.periodEnd);
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            return row is DateTime
                ? _DayHeader(day: row)
                : _SummaryTile(summary: row as ActivitySummary);
          },
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        formatDayHeader(l10n, day),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.summary});

  final ActivitySummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final label = switch (summary.kind) {
      SummaryKind.periodic => l10n.summaryAutoRecap,
      SummaryKind.dayRecap => l10n.summaryDayRecap,
      SummaryKind.manual => l10n.summaryMemory,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: textTheme.labelSmall),
              const Spacer(),
              Text(formatClockTime(l10n, summary.periodEnd),
                  style: textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 4),
          Text(summary.content, style: textTheme.bodySmall),
        ],
      ),
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
    final l10n = AppLocalizations.of(context);
    if (snippets == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snippets!.isEmpty) {
      return _SidebarMessage(text: l10n.noSnippetsYet);
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        snippet.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    CopyIconButton(text: snippet.content),
                  ],
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
                Text(formatRelativeTime(l10n, snippet.updatedAt),
                    style: textTheme.labelSmall),
              ],
            ),
          ),
        );
      },
    );
  }
}
