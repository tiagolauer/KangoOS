import 'package:flutter/material.dart';
import 'package:kangoos_core/kangoos_core.dart';

Future<MemorySearchFilters?> showMemoryFilterDialog({
  required BuildContext context,
  required MemoryService memory,
  required MemorySearchFilters initial,
  bool includeSnippets = true,
}) => showModalBottomSheet<MemorySearchFilters>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder:
      (context) => _MemoryFilterSheet(
        memory: memory,
        initial: initial,
        includeSnippets: includeSnippets,
      ),
);

class _MemoryFilterSheet extends StatefulWidget {
  const _MemoryFilterSheet({
    required this.memory,
    required this.initial,
    required this.includeSnippets,
  });

  final MemoryService memory;
  final MemorySearchFilters initial;
  final bool includeSnippets;

  @override
  State<_MemoryFilterSheet> createState() => _MemoryFilterSheetState();
}

class _MemoryFilterSheetState extends State<_MemoryFilterSheet> {
  late Set<MemoryEvidenceSource> _sources;
  late Set<String> _applications;
  late Set<MemoryModality> _modalities;
  late TextEditingController _projectController;
  late int _periodDays;
  late Future<List<String>> _knownApplications;

  @override
  void initState() {
    super.initState();
    _sources = {...widget.initial.sources};
    _applications = {...widget.initial.applications};
    _modalities = {...widget.initial.modalities};
    _projectController = TextEditingController(
      text: widget.initial.projects.join(', '),
    );
    _periodDays = _daysFor(widget.initial.start, widget.initial.end);
    _knownApplications = widget.memory.knownApplications();
  }

  @override
  void dispose() {
    _projectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sources = [
      MemoryEvidenceSource.episode,
      MemoryEvidenceSource.summary,
      MemoryEvidenceSource.durableMemory,
      MemoryEvidenceSource.conversation,
      if (widget.includeSnippets) MemoryEvidenceSource.snippet,
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
          child: ListView(
            shrinkWrap: true,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtros de memória',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  TextButton(onPressed: _clear, child: const Text('Limpar')),
                ],
              ),
              const SizedBox(height: 16),
              Text('FONTES', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final source in sources)
                    FilterChip(
                      label: Text(_sourceLabel(source)),
                      selected: _sources.contains(source),
                      onSelected:
                          (selected) => setState(() {
                            selected
                                ? _sources.add(source)
                                : _sources.remove(source);
                          }),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('PERÍODO', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _periodDays,
                decoration: const InputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Todo o histórico')),
                  DropdownMenuItem(value: 7, child: Text('Últimos 7 dias')),
                  DropdownMenuItem(value: 30, child: Text('Últimos 30 dias')),
                  DropdownMenuItem(value: 90, child: Text('Últimos 90 dias')),
                ],
                onChanged: (value) => setState(() => _periodDays = value ?? 0),
              ),
              const SizedBox(height: 20),
              Text('APLICAÇÕES', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              FutureBuilder<List<String>>(
                future: _knownApplications,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text('Não foi possível carregar: ${snapshot.error}');
                  }
                  final applications = snapshot.data ?? const [];
                  if (applications.isEmpty) {
                    return const Text('Nenhuma aplicação capturada ainda.');
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final application in applications)
                        FilterChip(
                          label: Text(application),
                          selected: _applications.contains(application),
                          onSelected:
                              (selected) => setState(() {
                                selected
                                    ? _applications.add(application)
                                    : _applications.remove(application);
                              }),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              Text('MODALIDADES', style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final modality in MemoryModality.values)
                    FilterChip(
                      label: Text(_modalityLabel(modality)),
                      selected: _modalities.contains(modality),
                      onSelected:
                          (selected) => setState(() {
                            selected
                                ? _modalities.add(modality)
                                : _modalities.remove(modality);
                          }),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _projectController,
                decoration: const InputDecoration(
                  labelText: 'Projetos',
                  hintText: 'Separe vários projetos por vírgula',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.check),
                label: const Text('Aplicar filtros'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clear() => setState(() {
    _sources.clear();
    _applications.clear();
    _modalities.clear();
    _projectController.clear();
    _periodDays = 0;
  });

  void _apply() {
    final now = DateTime.now();
    final projects =
        _projectController.text
            .split(',')
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toSet();
    Navigator.of(context).pop(
      MemorySearchFilters(
        sources: _sources,
        applications: _applications,
        modalities: _modalities,
        projects: projects,
        start:
            _periodDays == 0 ? null : now.subtract(Duration(days: _periodDays)),
        end: _periodDays == 0 ? null : now.add(const Duration(minutes: 1)),
      ),
    );
  }
}

int _daysFor(DateTime? start, DateTime? end) {
  if (start == null || end == null) return 0;
  final days = DateTime.now().difference(start).inDays;
  if (days <= 7) return 7;
  if (days <= 30) return 30;
  if (days <= 90) return 90;
  return 0;
}

String _sourceLabel(MemoryEvidenceSource source) => switch (source) {
  MemoryEvidenceSource.episode => 'Episódios',
  MemoryEvidenceSource.summary => 'Resumos',
  MemoryEvidenceSource.durableMemory => 'Memórias manuais',
  MemoryEvidenceSource.conversation => 'Conversas',
  MemoryEvidenceSource.snippet => 'Snippets',
};

String _modalityLabel(MemoryModality modality) => switch (modality) {
  MemoryModality.vision => 'Visão',
  MemoryModality.clipboard => 'Área de transferência',
  MemoryModality.browser => 'Navegador',
  MemoryModality.audio => 'Áudio',
  MemoryModality.metadata => 'Metadados',
};
