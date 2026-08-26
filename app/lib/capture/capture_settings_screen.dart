import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kangoos_core/kangoos_core.dart';

import '../autostart/autostart_service.dart';
import 'audio_capture_service.dart';
import 'capture_settings_repository.dart';
import 'capture_source_registry.dart';
import 'memory_deletion_dialog.dart';
import 'whisper_model_repository.dart';
import 'window_capture_service.dart';

class CaptureSettingsScreen extends StatefulWidget {
  const CaptureSettingsScreen({
    super.key,
    required this.repository,
    required this.memory,
    this.sourceRegistry,
    this.onRestoreStaged,
  });

  final CaptureSettingsRepository repository;
  final MemoryService memory;
  final CaptureSourceRegistry? sourceRegistry;
  final Future<void> Function()? onRestoreStaged;

  @override
  State<CaptureSettingsScreen> createState() => _CaptureSettingsScreenState();
}

class _CaptureSettingsScreenState extends State<CaptureSettingsScreen> {
  final _autostartService = AutostartService();
  final _modelRepository = WhisperModelRepository();
  late final CaptureSourceRegistry _sourceRegistry;
  var _modelReady = false;
  int? _modelDownloadPercent;
  String? _modelError;
  var _settings = const CaptureSettings();
  var _sources = <CaptureSource>[];
  var _autostartEnabled = false;
  var _loading = true;
  final _excludeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sourceRegistry = widget.sourceRegistry ?? CaptureSourceRegistry();
    _load();
  }

  Future<void> _load() async {
    final settings = await widget.repository.load();
    final sources = await _sourceRegistry.list();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _sources = sources;
      _autostartEnabled = _autostartService.isEnabled();
      _loading = false;
    });
    _refreshModelState();
  }

  Future<void> _refreshModelState() async {
    final ready = await _modelRepository.isDownloaded();
    if (mounted) setState(() => _modelReady = ready);
  }

  void _setAutostart(bool enabled) {
    _autostartService.setEnabled(enabled);
    setState(() => _autostartEnabled = enabled);
  }

  @override
  void dispose() {
    _excludeController.dispose();
    super.dispose();
  }

  Future<void> _apply(CaptureSettings updated) async {
    setState(() => _settings = updated);
    await widget.repository.save(updated);
  }

  Future<void> _pauseFor(Duration duration) => _apply(
        _settings.copyWith(
            paused: true, resumeAt: DateTime.now().add(duration)),
      );

  Future<void> _resumeNow() =>
      _apply(_settings.copyWith(paused: false, clearResumeAt: true));

  Future<void> _setSourceEnabled(CaptureSource source, bool enabled) async {
    await _sourceRegistry.setEnabled(source.id, enabled);
    await _reloadSources();
  }

  Future<void> _toggleSourceBlocked(CaptureSource source) async {
    await _sourceRegistry.setBlocked(source.id, !source.blocked);
    await _reloadSources();
  }

  Future<void> _reloadSources() async {
    final sources = await _sourceRegistry.list();
    if (mounted) setState(() => _sources = sources);
  }

  Future<void> _addExcludedApp() async {
    final app = _excludeController.text.trim();
    if (app.isEmpty ||
        WindowCaptureService.isExcluded(app, _settings.excludedApps)) {
      return;
    }
    _excludeController.clear();
    await _apply(
      _settings.copyWith(excludedApps: [..._settings.excludedApps, app]),
    );
  }

  Future<void> _removeExcludedApp(String app) => _apply(
        _settings.copyWith(
          excludedApps: _settings.excludedApps.where((a) => a != app).toList(),
        ),
      );

  Future<void> _downloadWhisperModel() async {
    setState(() {
      _modelDownloadPercent = 0;
      _modelError = null;
    });
    final result = await _modelRepository.download(
      onProgress: (received, total) {
        if (!mounted || total <= 0) return;
        setState(() => _modelDownloadPercent = (received * 100 ~/ total));
      },
    );
    if (!mounted) return;
    setState(() {
      _modelDownloadPercent = null;
      switch (result) {
        case ModelDownloadSuccess():
          _modelReady = true;
        case ModelDownloadFailure(message: final message):
          _modelError = message;
      }
    });
  }

  Future<void> _clearAllActivity() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearAllActivityTitle),
        content: Text(l10n.clearAllActivityBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonClear),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final cleared = await widget.memory.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.clearedEntries(
            cleared.activities,
            cleared.summaries + cleared.episodes,
          ),
        ),
      ),
    );
  }

  Future<void> _manageMemoryDeletion() async {
    final result = await showMemoryDeletionDialog(
      context: context,
      memory: widget.memory,
    );
    if (result == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.memoryDeletionCompleted(result.total))),
    );
  }

  Future<void> _createBackup() async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final location = await getSaveLocation(
      suggestedName: 'KangoOS-LTM-$date.db',
      acceptedTypeGroups: const [
        XTypeGroup(label: 'KangoOS LTM', extensions: ['db']),
      ],
    );
    if (location == null || !mounted) return;
    try {
      final backup = await widget.memory.createBackup(File(location.path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ltmBackupCreated(backup.path))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ltmBackupFailed('$error'))),
      );
    }
  }

  Future<void> _restoreBackup() async {
    final l10n = AppLocalizations.of(context);
    final selected = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'KangoOS LTM', extensions: ['db']),
      ],
    );
    if (selected == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.ltmRestoreTitle),
        content: Text(l10n.ltmRestoreBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.ltmRestoreConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.memory.stageRestore(File(selected.path));
      final restart = widget.onRestoreStaged;
      if (restart != null) {
        await restart();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ltmRestoreStaged)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.ltmRestoreFailed('$error'))),
      );
    }
  }

  String _sourceSubtitle(BuildContext context, CaptureSource source) {
    final l10n = AppLocalizations.of(context);
    final lastCapturedAt = source.lastCapturedAt;
    final captured = lastCapturedAt == null
        ? l10n.captureSourceNeverCaptured
        : l10n.captureSourceLastCaptured(
            MaterialLocalizations.of(context).formatShortDate(lastCapturedAt),
            MaterialLocalizations.of(
              context,
            ).formatTimeOfDay(TimeOfDay.fromDateTime(lastCapturedAt)),
          );
    final modalities = source.modalities.isEmpty
        ? l10n.captureSourceNoModalities
        : source.modalities.map((modality) {
            return switch (modality) {
              CaptureModality.metadata => l10n.captureModalityMetadata,
              CaptureModality.clipboard => l10n.captureModalityClipboard,
              CaptureModality.browser => l10n.captureModalityBrowser,
              CaptureModality.visibleText => l10n.captureModalityVisibleText,
              CaptureModality.screenText => l10n.captureModalityScreenText,
              CaptureModality.audio => l10n.captureModalityAudio,
            };
          }).join(', ');
    return '$captured • $modalities\n${source.id}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.activityCapture)),
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 820,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (AutostartService.isSupported)
                SwitchListTile(
                  title: Text(l10n.launchAtStartup),
                  subtitle: Text(l10n.launchAtStartupDescription),
                  value: _autostartEnabled,
                  onChanged: _setAutostart,
                ),
              SwitchListTile(
                title: Text(l10n.captureActiveWindow),
                subtitle: Text(l10n.captureActiveWindowDescription),
                value: !_settings.paused,
                onChanged: (enabled) => _apply(
                  _settings.copyWith(paused: !enabled, clearResumeAt: true),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pauseCaptureTemporarily,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (_settings.resumeAt case final resumeAt?) ...[
                        const SizedBox(height: 4),
                        Text(
                          l10n.capturePausedUntil(
                            MaterialLocalizations.of(
                              context,
                            ).formatTimeOfDay(TimeOfDay.fromDateTime(resumeAt)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () =>
                                _pauseFor(const Duration(minutes: 15)),
                            child: Text(l10n.pauseFor15Minutes),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                _pauseFor(const Duration(hours: 1)),
                            child: Text(l10n.pauseForOneHour),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                _pauseFor(const Duration(hours: 8)),
                            child: Text(l10n.pauseForEightHours),
                          ),
                          if (_settings.paused)
                            FilledButton.tonal(
                              onPressed: _resumeNow,
                              child: Text(l10n.resumeCaptureNow),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SwitchListTile(
                title: Text(l10n.captureBrowserUrls),
                subtitle: Text(l10n.captureBrowserUrlsDescription),
                value: _settings.captureBrowserUrls,
                onChanged: (enabled) =>
                    _apply(_settings.copyWith(captureBrowserUrls: enabled)),
              ),
              SwitchListTile(
                title: Text(l10n.captureVisibleText),
                subtitle: Text(l10n.captureVisibleTextDescription),
                value: _settings.captureVisibleText,
                onChanged: (enabled) =>
                    _apply(_settings.copyWith(captureVisibleText: enabled)),
              ),
              SwitchListTile(
                title: Text(l10n.captureScreenText),
                subtitle: Text(l10n.captureScreenTextDescription),
                value: _settings.captureScreenText,
                onChanged: (enabled) =>
                    _apply(_settings.copyWith(captureScreenText: enabled)),
              ),
              if (AudioCaptureService.isSupported) ...[
                SwitchListTile(
                  title: Text(l10n.captureAudio),
                  subtitle: Text(
                    l10n.captureAudioDescription(audioClipSeconds),
                  ),
                  value: _settings.captureAudio,
                  onChanged: _modelReady
                      ? (enabled) =>
                          _apply(_settings.copyWith(captureAudio: enabled))
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _modelError != null
                              ? l10n.whisperModelDownloadFailed(_modelError!)
                              : _modelDownloadPercent != null
                                  ? l10n.downloadingWhisperModel(
                                      _modelDownloadPercent!,
                                    )
                                  : _modelReady
                                      ? l10n.whisperModelReady
                                      : l10n.whisperModelMissing,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      if (!_modelReady)
                        TextButton(
                          onPressed: _modelDownloadPercent == null
                              ? _downloadWhisperModel
                              : null,
                          child: Text(l10n.downloadWhisperModel),
                        ),
                    ],
                  ),
                ),
              ],
              SwitchListTile(
                title: Text(l10n.captureClipboard),
                subtitle: Text(l10n.captureClipboardDescription),
                value: _settings.captureClipboard,
                onChanged: (enabled) =>
                    _apply(_settings.copyWith(captureClipboard: enabled)),
              ),
              SwitchListTile(
                title: Text(l10n.allowRemoteSummaries),
                subtitle: Text(l10n.allowRemoteSummariesDescription),
                value: _settings.allowRemoteSummaries,
                onChanged: (enabled) => _apply(
                  _settings.copyWith(allowRemoteSummaries: enabled),
                ),
              ),
              SwitchListTile(
                title: Text(l10n.redactCapturedPii),
                subtitle: Text(l10n.redactCapturedPiiDescription),
                value: _settings.redactPii,
                onChanged: (enabled) =>
                    _apply(_settings.copyWith(redactPii: enabled)),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.keepHistoryFor,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(l10n.keepHistoryDescription),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _settings.retentionDays,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final days in const [7, 30, 90])
                    DropdownMenuItem(
                      value: days,
                      child: Text(l10n.retentionDays(days)),
                    ),
                  DropdownMenuItem(
                    value: 0,
                    child: Text(l10n.retentionForever),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    _apply(_settings.copyWith(retentionDays: value));
                  }
                },
              ),
              const SizedBox(height: 16),
              Text(
                l10n.knownCaptureSources,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(l10n.knownCaptureSourcesDescription),
              const SizedBox(height: 8),
              if (_sources.isEmpty)
                ListTile(
                  leading: const Icon(Icons.apps_outlined),
                  title: Text(l10n.noKnownCaptureSources),
                ),
              for (final source in _sources)
                Card(
                  child: ListTile(
                    leading: Icon(
                      source.blocked
                          ? Icons.block
                          : Icons.desktop_windows_outlined,
                    ),
                    title: Text(source.name),
                    subtitle: Text(_sourceSubtitle(context, source)),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _toggleSourceBlocked(source),
                          icon: Icon(
                            source.blocked
                                ? Icons.lock_open_outlined
                                : Icons.block,
                          ),
                          tooltip: source.blocked
                              ? l10n.unblockCaptureSource
                              : l10n.blockCaptureSource,
                        ),
                        Switch(
                          value: source.enabled,
                          onChanged: source.blocked
                              ? null
                              : (enabled) => _setSourceEnabled(source, enabled),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                l10n.excludedApps,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(l10n.excludedAppsDescription),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _excludeController,
                      decoration: InputDecoration(
                        hintText: l10n.excludedAppHint,
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addExcludedApp(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addExcludedApp,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final app in _settings.excludedApps)
                ListTile(
                  dense: true,
                  title: Text(app),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => _removeExcludedApp(app),
                  ),
                ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.privacyLifecycleTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(l10n.privacyLifecycleDescription),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _manageMemoryDeletion,
                            icon: const Icon(Icons.tune),
                            label: Text(l10n.manageMemoryDeletion),
                          ),
                          OutlinedButton.icon(
                            onPressed: _createBackup,
                            icon: const Icon(Icons.archive_outlined),
                            label: Text(l10n.createLtmBackup),
                          ),
                          OutlinedButton.icon(
                            onPressed: _restoreBackup,
                            icon: const Icon(Icons.restore_outlined),
                            label: Text(l10n.restoreLtmBackup),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _clearAllActivity,
                icon: const Icon(Icons.delete_forever_outlined),
                label: Text(l10n.clearAllActivity),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
