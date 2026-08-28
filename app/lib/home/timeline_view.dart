import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kangoos_core/kangoos_core.dart';

import '../confirm_dialog.dart';
import 'memory_filter_dialog.dart';
import 'timeline_service.dart';

class TimelineView extends StatefulWidget {
  const TimelineView({super.key, required this.service, required this.memory});

  final TimelineService service;
  final MemoryService memory;

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  static const _debounce = Duration(milliseconds: 280);

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _types = <TimelineItemType>{};
  var _filters = const MemorySearchFilters();
  var _mode = MemorySearchMode.lexical;
  var _favoritesOnly = false;
  Timer? _timer;
  late Future<List<TimelineItem>> _items;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _reload() {
    _items = widget.service.search(
      TimelineQuery(
        text: _searchController.text.trim(),
        mode: _mode,
        filters: _filters,
        types: _types,
        favoritesOnly: _favoritesOnly,
      ),
    );
  }

  void _refresh() => setState(_reload);

  void _onSearchChanged(String _) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (mounted) _refresh();
    });
  }

  Future<void> _openFilters() async {
    final selected = await showMemoryFilterDialog(
      context: context,
      memory: widget.memory,
      initial: _filters,
      includeSnippets: false,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _filters = selected;
      _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _searchFocus.requestFocus,
      },
      child: FocusTraversalGroup(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('timeline-search'),
                      controller: _searchController,
                      focusNode: _searchFocus,
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Buscar na Timeline',
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                    ),
                  ),
                  IconButton(
                    isSelected: _mode == MemorySearchMode.semantic,
                    onPressed:
                        () => setState(() {
                          _mode =
                              _mode == MemorySearchMode.semantic
                                  ? MemorySearchMode.lexical
                                  : MemorySearchMode.semantic;
                          _reload();
                        }),
                    icon: Icon(
                      _mode == MemorySearchMode.semantic
                          ? Icons.auto_awesome
                          : Icons.text_fields,
                      size: 18,
                    ),
                    tooltip:
                        _mode == MemorySearchMode.semantic
                            ? 'Busca semântica ativa'
                            : 'Busca lexical ativa',
                  ),
                  IconButton(
                    onPressed: _openFilters,
                    icon: Badge(
                      isLabelVisible: _hasMemoryFilters,
                      child: const Icon(Icons.tune, size: 19),
                    ),
                    tooltip: 'Filtrar aplicação, modalidade, período e projeto',
                  ),
                  IconButton(
                    isSelected: _favoritesOnly,
                    onPressed:
                        () => setState(() {
                          _favoritesOnly = !_favoritesOnly;
                          _reload();
                        }),
                    icon: Icon(
                      _favoritesOnly ? Icons.star : Icons.star_border,
                      size: 20,
                    ),
                    tooltip: 'Somente favoritos',
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final type in TimelineItemType.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        visualDensity: VisualDensity.compact,
                        label: Text(_typeLabel(type)),
                        selected: _types.contains(type),
                        onSelected:
                            (selected) => setState(() {
                              selected ? _types.add(type) : _types.remove(type);
                              _reload();
                            }),
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant),
            Expanded(
              child: FutureBuilder<List<TimelineItem>>(
                future: _items,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Semantics(
                      liveRegion: true,
                      label: 'Carregando Timeline',
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _TimelineState(
                      icon: Icons.error_outline,
                      message:
                          'Não foi possível carregar a Timeline.\n${snapshot.error}',
                      actionLabel: 'Tentar novamente',
                      onAction: _refresh,
                    );
                  }
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return _TimelineState(
                      icon: Icons.route_outlined,
                      message: 'Nenhum item corresponde aos filtros atuais.',
                      actionLabel: 'Limpar filtros',
                      onAction: _clearFilters,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _TimelineTile(
                          item: item,
                          onOpen: () => _openDetails(item),
                          onFavorite: () => _toggleFavorite(item),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasMemoryFilters =>
      _filters.sources.isNotEmpty ||
      _filters.applications.isNotEmpty ||
      _filters.modalities.isNotEmpty ||
      _filters.projects.isNotEmpty ||
      _filters.start != null ||
      _filters.end != null;

  void _clearFilters() => setState(() {
    _filters = const MemorySearchFilters();
    _types.clear();
    _favoritesOnly = false;
    _searchController.clear();
    _reload();
  });

  Future<void> _toggleFavorite(TimelineItem item) async {
    await widget.service.toggleFavorite(item);
    if (mounted) _refresh();
  }

  Future<void> _openDetails(TimelineItem item) async {
    final deleted = await showDialog<bool>(
      context: context,
      builder:
          (context) => _TimelineDetails(
            item: item,
            related: widget.service.relatedActivities(item),
            onDelete: () async {
              final confirmed = await confirmDestructiveAction(
                context: context,
                title: 'Excluir da memória?',
                body:
                    'O conteúdo será removido da fonte original e não poderá ser recuperado.',
                confirmLabel: 'Excluir',
              );
              if (!confirmed || !context.mounted) return;
              await widget.service.delete(item);
              if (context.mounted) Navigator.of(context).pop(true);
            },
          ),
    );
    if (deleted == true && mounted) _refresh();
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.item,
    required this.onOpen,
    required this.onFavorite,
  });

  final TimelineItem item;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = MaterialLocalizations.of(context);
    return Semantics(
      button: true,
      label: '${_typeLabel(item.type)}: ${item.title}',
      child: InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _typeIcon(item.type),
                size: 19,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.content.isEmpty
                          ? _typeLabel(item.type)
                          : item.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      l10n.formatTimeOfDay(
                        TimeOfDay.fromDateTime(item.endedAt),
                      ),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onFavorite,
                icon: Icon(item.favorite ? Icons.star : Icons.star_border),
                color: item.favorite ? theme.colorScheme.secondary : null,
                tooltip: item.favorite ? 'Remover dos favoritos' : 'Favoritar',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineDetails extends StatelessWidget {
  const _TimelineDetails({
    required this.item,
    required this.related,
    required this.onDelete,
  });

  final TimelineItem item;
  final Future<List<Activity>> related;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(_typeIcon(item.type), color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(item.title)),
        ],
      ),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_typeLabel(item.type), style: theme.textTheme.labelSmall),
              const SizedBox(height: 12),
              SelectableText(
                item.content.isEmpty ? 'Sem conteúdo textual.' : item.content,
              ),
              const SizedBox(height: 24),
              Text('FONTES', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              SelectableText(
                [
                  item.key,
                  if (item.applications.isNotEmpty)
                    'Aplicações: ${item.applications.join(', ')}',
                  if (item.modalities.isNotEmpty)
                    'Modalidades: ${item.modalities.map((value) => value.name).join(', ')}',
                  if (item.projects.isNotEmpty)
                    'Projetos: ${item.projects.join(', ')}',
                  '${item.startedAt.toLocal()} — ${item.endedAt.toLocal()}',
                ].join('\n'),
              ),
              const SizedBox(height: 24),
              Text('EVENTOS RELACIONADOS', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              FutureBuilder<List<Activity>>(
                future: related,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text('Não foi possível carregar: ${snapshot.error}');
                  }
                  final activities = snapshot.data ?? const [];
                  if (activities.isEmpty) {
                    return const Text('Nenhum evento relacionado.');
                  }
                  return Column(
                    children: [
                      for (final activity in activities.take(12))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.bolt_outlined, size: 18),
                          title: Text(activity.windowTitle),
                          subtitle: Text(activity.appName),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Excluir'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

class _TimelineState extends StatelessWidget {
  const _TimelineState({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 30),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

String _typeLabel(TimelineItemType type) => switch (type) {
  TimelineItemType.event => 'Eventos',
  TimelineItemType.episode => 'Episódios',
  TimelineItemType.summary => 'Resumos',
  TimelineItemType.manualMemory => 'Memórias',
  TimelineItemType.conversation => 'Conversas',
  TimelineItemType.deepStudyReport => 'DeepStudy',
};

IconData _typeIcon(TimelineItemType type) => switch (type) {
  TimelineItemType.event => Icons.bolt_outlined,
  TimelineItemType.episode => Icons.layers_outlined,
  TimelineItemType.summary => Icons.summarize_outlined,
  TimelineItemType.manualMemory => Icons.bookmark_outline,
  TimelineItemType.conversation => Icons.forum_outlined,
  TimelineItemType.deepStudyReport => Icons.manage_search,
};
