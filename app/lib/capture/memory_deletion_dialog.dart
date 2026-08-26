import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kangoos_core/kangoos_core.dart';

Future<MemoryDeletionResult?> showMemoryDeletionDialog({
  required BuildContext context,
  required MemoryService memory,
}) => showDialog<MemoryDeletionResult>(
  context: context,
  builder: (context) => _MemoryDeletionDialog(memory: memory),
);

class _MemoryDeletionDialog extends StatefulWidget {
  const _MemoryDeletionDialog({required this.memory});

  final MemoryService memory;

  @override
  State<_MemoryDeletionDialog> createState() => _MemoryDeletionDialogState();
}

class _MemoryDeletionDialogState extends State<_MemoryDeletionDialog> {
  late DateTimeRange _range;
  var _allHistory = false;
  var _applications = <String>[];
  final _selectedApplications = <String>{};
  final _modalities = <MemoryModality>{};
  final _memoryTypes = {...defaultDeletableMemoryTypes};
  MemoryDeletionPreview? _preview;
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _range = DateTimeRange(
      start: today.subtract(const Duration(days: 6)),
      end: today,
    );
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    final applications = await widget.memory.knownApplications();
    if (mounted) setState(() => _applications = applications);
  }

  void _changed(VoidCallback change) {
    setState(() {
      change();
      _preview = null;
      _error = null;
    });
  }

  MemoryDeletionFilter _filter() => MemoryDeletionFilter(
    start: _allHistory ? null : _range.start,
    end: _allHistory ? null : _range.end.add(const Duration(days: 1)),
    applications: _selectedApplications,
    modalities: _modalities,
    memoryTypes: _memoryTypes,
  );

  Future<void> _selectRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (selected != null) _changed(() => _range = selected);
  }

  Future<void> _previewDeletion() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await widget.memory.previewDeletion(_filter());
      if (mounted) setState(() => _preview = preview);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final preview = _preview;
    if (preview == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.memoryDeletionConfirmTitle),
            content: Text(
              l10n.memoryDeletionPreviewCounts(
                preview.activities,
                preview.episodes,
                preview.summaries,
                preview.embeddings,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.memoryDeletionDelete),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await widget.memory.delete(_filter());
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localizations = MaterialLocalizations.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.memoryDeletionTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                  ),
                ],
              ),
              Text(l10n.memoryDeletionDescription),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.memoryDeletionAllHistory),
                        value: _allHistory,
                        onChanged:
                            _busy
                                ? null
                                : (value) =>
                                    _changed(() => _allHistory = value),
                      ),
                      if (!_allHistory)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.date_range_outlined),
                          title: Text(l10n.memoryDeletionDateRange),
                          subtitle: Text(
                            '${localizations.formatShortDate(_range.start)} — '
                            '${localizations.formatShortDate(_range.end)}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _busy ? null : _selectRange,
                        ),
                      const Divider(),
                      _SectionTitle(
                        title: l10n.memoryDeletionApplications,
                        helper: l10n.memoryDeletionEmptyMeansAll,
                      ),
                      if (_applications.isEmpty)
                        Text(l10n.memoryDeletionNoApplications)
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final application in _applications)
                              FilterChip(
                                label: Text(application),
                                selected: _selectedApplications.contains(
                                  application,
                                ),
                                onSelected:
                                    _busy
                                        ? null
                                        : (selected) => _changed(() {
                                          if (selected) {
                                            _selectedApplications.add(
                                              application,
                                            );
                                          } else {
                                            _selectedApplications.remove(
                                              application,
                                            );
                                          }
                                        }),
                              ),
                          ],
                        ),
                      const SizedBox(height: 20),
                      _SectionTitle(
                        title: l10n.memoryDeletionModalities,
                        helper: l10n.memoryDeletionEmptyMeansAll,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final modality in MemoryModality.values)
                            FilterChip(
                              label: Text(_modalityLabel(l10n, modality)),
                              selected: _modalities.contains(modality),
                              onSelected:
                                  _busy
                                      ? null
                                      : (selected) => _changed(() {
                                        if (selected) {
                                          _modalities.add(modality);
                                        } else {
                                          _modalities.remove(modality);
                                        }
                                      }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _SectionTitle(
                        title: l10n.memoryDeletionTypes,
                        helper: l10n.memoryDeletionProtectedHint,
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final type in MemoryType.values)
                            FilterChip(
                              label: Text(_memoryTypeLabel(l10n, type)),
                              selected: _memoryTypes.contains(type),
                              onSelected:
                                  _busy
                                      ? null
                                      : (selected) => _changed(() {
                                        if (selected) {
                                          _memoryTypes.add(type);
                                        } else {
                                          _memoryTypes.remove(type);
                                        }
                                      }),
                            ),
                        ],
                      ),
                      if (_preview case final preview?) ...[
                        const SizedBox(height: 20),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(Icons.fact_check_outlined),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    l10n.memoryDeletionPreviewCounts(
                                      preview.activities,
                                      preview.episodes,
                                      preview.summaries,
                                      preview.embeddings,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (_error case final error?) ...[
                        const SizedBox(height: 12),
                        Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                  OutlinedButton(
                    onPressed:
                        _busy || _memoryTypes.isEmpty ? null : _previewDeletion,
                    child: Text(l10n.memoryDeletionPreview),
                  ),
                  FilledButton.icon(
                    onPressed: _busy || _preview == null ? null : _delete,
                    icon:
                        _busy
                            ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.delete_outline),
                    label: Text(l10n.memoryDeletionDelete),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.helper});

  final String title;
  final String helper;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Text(helper, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

String _modalityLabel(AppLocalizations l10n, MemoryModality modality) =>
    switch (modality) {
      MemoryModality.vision => l10n.memoryModalityVision,
      MemoryModality.clipboard => l10n.captureModalityClipboard,
      MemoryModality.browser => l10n.captureModalityBrowser,
      MemoryModality.audio => l10n.captureModalityAudio,
      MemoryModality.metadata => l10n.captureModalityMetadata,
    };

String _memoryTypeLabel(AppLocalizations l10n, MemoryType type) =>
    switch (type) {
      MemoryType.activity => l10n.memoryTypeActivity,
      MemoryType.episode => l10n.memoryTypeEpisode,
      MemoryType.automaticSummary => l10n.memoryTypeAutomaticSummary,
      MemoryType.manualSummary => l10n.memoryTypeManualSummary,
      MemoryType.durableMemory => l10n.memoryTypeDurable,
    };
