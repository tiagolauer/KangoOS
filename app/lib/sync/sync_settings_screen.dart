import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kangoos_core/kangoos_core.dart';

import 'sync_settings_repository.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({
    super.key,
    required this.repository,
    required this.database,
    this.semanticSearch,
  });

  final SyncSettingsRepository repository;
  final KangoosDatabase database;
  final SemanticSearch? semanticSearch;

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
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).settingsSaved)));
  }

  Future<void> _syncNow() async {
    final l10n = AppLocalizations.of(context);
    final url = _urlController.text.trim();
    final token = _tokenController.text.trim();
    if (url.isEmpty || token.isEmpty) {
      setState(() => _status = l10n.syncSetUrlAndTokenFirst);
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
        semanticSearch: widget.semanticSearch,
      );
      final result = await client.sync();
      setState(() => _status = l10n.syncSucceeded(
            result.pushed,
            result.pulled,
            result.updated,
            result.deletedLocally + result.deletedRemotely,
          ));
    } catch (e) {
      setState(() => _status = l10n.syncFailed('$e'));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.serverSync),
        actions: [
          IconButton(
              onPressed: _save,
              icon: const Icon(Icons.check),
              tooltip: l10n.commonSave),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(l10n.serverSyncDescription),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: l10n.serverUrl,
                hintText: 'http://localhost:8080',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(labelText: l10n.serverApiToken),
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
              label: Text(l10n.syncNow),
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
