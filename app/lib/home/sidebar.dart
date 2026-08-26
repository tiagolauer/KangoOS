import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kangoos_core/kangoos_core.dart';

import '../copy_button.dart';
import 'relative_time.dart';

enum SidebarTab { snippets, activity, timeline }

class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    required this.snippets,
    required this.memory,
    required this.onSelectSnippet,
    required this.onCreateSnippet,
    required this.onGenerateDayRecap,
    this.width = 352,
  });

  final SnippetService snippets;
  final MemoryService memory;
  final void Function(Snippet snippet) onSelectSnippet;
  final VoidCallback onCreateSnippet;
  final Future<SummaryResult> Function(CancelToken cancelToken)
      onGenerateDayRecap;
  final double? width;

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
    return widget.snippets.search(
      query,
      mode: _semantic ? SnippetSearchMode.semantic : SnippetSearchMode.keyword,
    );
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
        SummaryFailure(error: SummaryError.llmFailed) => l10n.dayRecapLlmFailed,
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
    final title = switch (_tab) {
      SidebarTab.snippets => l10n.tabSnippets,
      SidebarTab.activity => l10n.tabActivity,
      SidebarTab.timeline => l10n.tabTimeline,
    };
    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.outline)),
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: Text(
                    'K',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 26),
                _SidebarRailButton(
                  icon: Icons.data_object,
                  label: l10n.tabSnippets,
                  selected: _tab == SidebarTab.snippets,
                  onTap: () => setState(() => _tab = SidebarTab.snippets),
                ),
                const SizedBox(height: 8),
                _SidebarRailButton(
                  icon: Icons.monitor_heart_outlined,
                  label: l10n.tabActivity,
                  selected: _tab == SidebarTab.activity,
                  onTap: () => setState(() => _tab = SidebarTab.activity),
                ),
                const SizedBox(height: 8),
                _SidebarRailButton(
                  icon: Icons.route_outlined,
                  label: l10n.tabTimeline,
                  selected: _tab == SidebarTab.timeline,
                  onTap: () => setState(() => _tab = SidebarTab.timeline),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Icon(Icons.lock_outline,
                      size: 18, color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: colors.outlineVariant),
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: 78,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 10, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(l10n.personalArchive,
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                              const SizedBox(height: 4),
                              Text(title,
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                            ],
                          ),
                        ),
                        if (_tab == SidebarTab.snippets)
                          IconButton(
                            onPressed: widget.onCreateSnippet,
                            icon: const Icon(Icons.add),
                            tooltip: l10n.newSnippet,
                          ),
                        if (_tab == SidebarTab.timeline)
                          IconButton(
                            onPressed: _generatingRecap
                                ? () => _recapCancelToken?.cancel()
                                : _generateDayRecap,
                            icon: Icon(_generatingRecap
                                ? Icons.stop
                                : Icons.auto_awesome),
                            tooltip: _generatingRecap
                                ? l10n.stopGenerating
                                : l10n.generateDayRecap,
                          ),
                      ],
                    ),
                  ),
                ),
                if (_tab == SidebarTab.snippets)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
                    child: TextField(
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: _semantic
                            ? l10n.filterSnippetsSemantic
                            : l10n.filterSnippets,
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _semantic
                                  ? Icons.auto_awesome
                                  : Icons.text_fields,
                              size: 17),
                          tooltip: _semantic
                              ? l10n.switchToKeywordSearch
                              : l10n.switchToSemanticSearch,
                          onPressed: _toggleSemantic,
                        ),
                      ),
                      onChanged: _onQueryChanged,
                    ),
                  ),
                Divider(color: colors.outlineVariant),
                Expanded(
                  child: switch (_tab) {
                    SidebarTab.snippets => _buildSnippets(context),
                    SidebarTab.activity => _buildActivity(context),
                    SidebarTab.timeline => _buildTimeline(context),
                  },
                ),
              ],
            ),
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
        stream: widget.snippets.watchAll(),
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
      stream: widget.memory.watchRecentActivities(),
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
    await widget.memory.deleteActivity(activity.id);

    messenger.showSnackBar(SnackBar(
      content: Text(l10n.activityDeleted),
      action: SnackBarAction(
        label: l10n.commonUndo,
        onPressed: () => widget.memory.record(
          NewActivity(
            appName: activity.appName,
            windowTitle: activity.windowTitle,
            capturedText: activity.capturedText,
            capturedUrl: activity.capturedUrl,
            capturedClipboard: activity.capturedClipboard,
            capturedScreenText: activity.capturedScreenText,
            capturedAudioText: activity.capturedAudioText,
            capturedAt: activity.capturedAt,
          ),
        ),
      ),
    ));
  }

  Widget _buildTimeline(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StreamBuilder<List<ActivitySummary>>(
      stream: widget.memory.watchRecentSummaries(),
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

class _SidebarRailButton extends StatelessWidget {
  const _SidebarRailButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 42,
              height: 42,
              child: Icon(
                icon,
                size: 20,
                color: selected ? colors.onPrimary : colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
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
      SummaryKind.periodic || SummaryKind.session => l10n.summaryAutoRecap,
      SummaryKind.dayRecap ||
      SummaryKind.daily ||
      SummaryKind.weekly =>
        l10n.summaryDayRecap,
      SummaryKind.manual || SummaryKind.durable => l10n.summaryMemory,
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        border: Border(
          bottom:
              BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 28,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: snippets!.length,
      itemBuilder: (context, index) {
        final snippet = snippets![index];
        final colors = Theme.of(context).colorScheme;
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTap(snippet),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.outlineVariant),
                ),
              ),
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
                      child: Text(snippet.language!.toUpperCase(),
                          style: textTheme.labelSmall
                              ?.copyWith(color: colors.primary)),
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
          ),
        );
      },
    );
  }
}
