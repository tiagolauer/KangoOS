import 'package:flutter/material.dart';
import 'package:kangoos_core/kangoos_core.dart';

import 'sync_settings_repository.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({
    super.key,
    required this.repository,
    required this.database,
  });

  final SyncSettingsRepository repository;
  final KangoosDatabase database;

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  var _loading = true;
  var _syncing = false;
  String? _status;
  late final _urlController = TextEditingController();
  late final _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await widget.repository.load();
    setState(() {
      _urlController.text = settings.serverUrl;
      _tokenController.text = settings.apiToken;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.repository.save(SyncSettings(
      serverUrl: _urlController.text.trim(),
      apiToken: _tokenController.text.trim(),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  Future<void> _syncNow() async {
    final url = _urlController.text.trim();
    final token = _tokenController.text.trim();
    if (url.isEmpty || token.isEmpty) {
      setState(() => _status = 'Set a server URL and API token first.');
      return;
    }

    await widget.repository
        .save(SyncSettings(serverUrl: url, apiToken: token));
    setState(() {
      _syncing = true;
      _status = null;
    });
    try {
      final client = SnippetSyncClient(
        database: widget.database,
        baseUrl: Uri.parse(url),
        apiToken: token,
      );
      final result = await client.sync();
      setState(() => _status = 'Synced: ${result.pushed} pushed, '
          '${result.pulled} pulled, ${result.updated} updated.');
    } catch (e) {
      setState(() => _status = 'Sync failed: $e');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server sync'),
        actions: [
          IconButton(
              onPressed: _save, icon: const Icon(Icons.check), tooltip: 'Save'),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Sync snippets with a self-hosted KangoOS server. Snippets '
              'only — captured activity and chat history stay on this '
              'device. Deleting a snippet on one side does not delete it '
              'on the other yet.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://localhost:8080',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(labelText: 'API token'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _syncing ? null : _syncNow,
              icon: _syncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
              label: const Text('Sync now'),
            ),
            if (_status != null) ...[
              const SizedBox(height: 12),
              Text(_status!),
            ],
          ],
        ),
      ),
    );
  }
}
