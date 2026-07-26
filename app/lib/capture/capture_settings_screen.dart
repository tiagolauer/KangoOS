import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kangoos_core/kangoos_core.dart';

import '../autostart/autostart_service.dart';
import 'capture_settings_repository.dart';

class CaptureSettingsScreen extends StatefulWidget {
  const CaptureSettingsScreen({
    super.key,
    required this.repository,
    required this.database,
  });

  final CaptureSettingsRepository repository;
  final KangoosDatabase database;

  @override
  State<CaptureSettingsScreen> createState() => _CaptureSettingsScreenState();
}

class _CaptureSettingsScreenState extends State<CaptureSettingsScreen> {
  final _autostartService = AutostartService();
  var _settings = const CaptureSettings();
  var _autostartEnabled = false;
  var _loading = true;
  final _excludeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await widget.repository.load();
    setState(() {
      _settings = settings;
      _autostartEnabled = _autostartService.isEnabled();
      _loading = false;
    });
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

  Future<void> _addExcludedApp() async {
    final app = _excludeController.text.trim();
    if (app.isEmpty || _settings.excludedApps.contains(app)) return;
    _excludeController.clear();
    await _apply(
        _settings.copyWith(excludedApps: [..._settings.excludedApps, app]));
  }

  Future<void> _removeExcludedApp(String app) => _apply(
        _settings.copyWith(
          excludedApps: _settings.excludedApps.where((a) => a != app).toList(),
        ),
      );

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

    final activityCount = await widget.database.clearAllActivity();
    final summaryCount = await widget.database.clearAllSummaries();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(l10n.clearedEntries(activityCount, summaryCount))));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.activityCapture)),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
            subtitle: Text(
              l10n.captureActiveWindowDescription,
            ),
            value: !_settings.paused,
            onChanged: (enabled) =>
                _apply(_settings.copyWith(paused: !enabled)),
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
          SwitchListTile(
            title: Text(l10n.captureClipboard),
            subtitle: Text(l10n.captureClipboardDescription),
            value: _settings.captureClipboard,
            onChanged: (enabled) =>
                _apply(_settings.copyWith(captureClipboard: enabled)),
          ),
          const SizedBox(height: 16),
          Text(l10n.keepHistoryFor,
              style: Theme.of(context).textTheme.titleMedium),
          Text(l10n.keepHistoryDescription),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _settings.retentionDays,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), isDense: true),
            items: [
              for (final days in const [7, 30, 90])
                DropdownMenuItem(
                    value: days, child: Text(l10n.retentionDays(days))),
              DropdownMenuItem(value: 0, child: Text(l10n.retentionForever)),
            ],
            onChanged: (value) {
              if (value != null) {
                _apply(_settings.copyWith(retentionDays: value));
              }
            },
          ),
          const SizedBox(height: 16),
          Text(l10n.excludedApps, style: Theme.of(context).textTheme.titleMedium),
          Text(l10n.excludedAppsDescription),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _excludeController,
                  decoration: const InputDecoration(
                    hintText: 'process name, e.g. keepass.exe',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addExcludedApp(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                  onPressed: _addExcludedApp, icon: const Icon(Icons.add)),
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
    );
  }
}
