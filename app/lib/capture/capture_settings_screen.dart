import 'package:flutter/material.dart';

import 'capture_settings_repository.dart';

class CaptureSettingsScreen extends StatefulWidget {
  const CaptureSettingsScreen({super.key, required this.repository});

  final CaptureSettingsRepository repository;

  @override
  State<CaptureSettingsScreen> createState() => _CaptureSettingsScreenState();
}

class _CaptureSettingsScreenState extends State<CaptureSettingsScreen> {
  var _settings = const CaptureSettings();
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
      _loading = false;
    });
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
    await _apply(_settings.copyWith(excludedApps: [..._settings.excludedApps, app]));
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
          SwitchListTile(
            title: const Text('Capture active window'),
            subtitle: const Text(
              'Records the app and window title every few seconds while '
              'KangoOS is open. No content is captured, only what app/window '
              'was active.',
            ),
            value: !_settings.paused,
            onChanged: (enabled) => _apply(_settings.copyWith(paused: !enabled)),
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
              IconButton(onPressed: _addExcludedApp, icon: const Icon(Icons.add)),
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
