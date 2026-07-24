import 'package:flutter/material.dart';
import 'package:kangoos_core/kangoos_core.dart';

import 'settings_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.repository});

  final SettingsRepository repository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  var _settings = LlmSettings.defaults;
  var _loading = true;

  late final _modelController = TextEditingController();
  late final _apiKeyController = TextEditingController();
  late final _baseUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await widget.repository.load();
    setState(() {
      _settings = settings;
      _modelController.text = settings.model;
      _apiKeyController.text = settings.apiKey;
      _baseUrlController.text = settings.baseUrl;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _modelController.dispose();
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = _settings.copyWith(
      model: _modelController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
    );
    await widget.repository.save(settings);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final needsApiKey = _settings.provider != LlmProviderKind.ollama;
    final isOllama = _settings.provider == LlmProviderKind.ollama;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LLM settings'),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.check), tooltip: 'Save'),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            DropdownButtonFormField<LlmProviderKind>(
              value: _settings.provider,
              decoration: const InputDecoration(labelText: 'Provider'),
              items: LlmProviderKind.values
                  .map((kind) => DropdownMenuItem(value: kind, child: Text(_label(kind))))
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _settings = _settings.copyWith(provider: value));
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(labelText: 'Model'),
            ),
            if (needsApiKey) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                decoration: const InputDecoration(labelText: 'API key'),
                obscureText: true,
              ),
            ],
            if (isOllama) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Base URL (optional)',
                  hintText: 'http://localhost:11434',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _label(LlmProviderKind provider) {
    switch (provider) {
      case LlmProviderKind.ollama:
        return 'Ollama (local)';
      case LlmProviderKind.anthropic:
        return 'Anthropic';
      case LlmProviderKind.openAi:
        return 'OpenAI';
    }
  }
}
