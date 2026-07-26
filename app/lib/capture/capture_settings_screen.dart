import 'package:flutter/material.dart';

import '../autostart/autostart_service.dart';
import 'capture_settings_repository.dart';

class CaptureSettingsScreen extends StatefulWidget {
  const CaptureSettingsScreen({super.key, required this.repository});

  final CaptureSettingsRepository repository;

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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Activity capture')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (AutostartService.isSupported)
            SwitchListTile(
              title: const Text('Launch KangoOS at startup'),
              subtitle: const Text(
                'Starts KangoOS minimized to the tray when you sign in, so '
                'capture runs without opening the window.',
              ),
              value: _autostartEnabled,
              onChanged: _setAutostart,
            ),
          SwitchListTile(
            title: const Text('Capture active window'),
            subtitle: const Text(
              'Records the app and window title every few seconds while '
              'KangoOS is open.',
            ),
            value: !_settings.paused,
            onChanged: (enabled) =>
                _apply(_settings.copyWith(paused: !enabled)),
          ),
          SwitchListTile(
            title: const Text('Capture browser URLs'),
            subtitle: const Text(
              'Also records the active tab\'s URL for Chrome/Edge/Brave/Safari. '
              'This is content, not just metadata: off by default. On Windows/'
              'Linux this reads the address bar via accessibility APIs '
              '(best-effort, may not always work); on macOS it requires '
              'granting Accessibility permission to KangoOS.',
            ),
            value: _settings.captureBrowserUrls,
            onChanged: (enabled) =>
                _apply(_settings.copyWith(captureBrowserUrls: enabled)),
          ),
          SwitchListTile(
            title: const Text('Capture visible text (experimental)'),
            subtitle: const Text(
              'Also records the text you were focused on (e.g. what a text '
              'field contains), via Windows UI Automation. Runs in a separate '
              'helper process so a crash there never affects KangoOS, but it '
              'means this may silently capture nothing on some systems.',
            ),
            value: _settings.captureVisibleText,
            onChanged: (enabled) =>
                _apply(_settings.copyWith(captureVisibleText: enabled)),
          ),
          const SizedBox(height: 16),
          Text('Keep history for',
              style: Theme.of(context).textTheme.titleMedium),
          const Text('Older activity is purged automatically.'),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _settings.retentionDays,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), isDense: true),
            items: const [
              DropdownMenuItem(value: 7, child: Text('7 days')),
              DropdownMenuItem(value: 30, child: Text('30 days')),
              DropdownMenuItem(value: 90, child: Text('90 days')),
              DropdownMenuItem(value: 0, child: Text('Forever')),
            ],
            onChanged: (value) {
              if (value != null) {
                _apply(_settings.copyWith(retentionDays: value));
              }
            },
          ),
          const SizedBox(height: 16),
          Text('Excluded apps', style: Theme.of(context).textTheme.titleMedium),
          const Text('Never captured, e.g. a password manager or banking app.'),
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
        ],
      ),
    );
  }
}
