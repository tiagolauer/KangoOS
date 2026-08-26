import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
  late final _embeddingModelController = TextEditingController();

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
      _embeddingModelController.text = settings.embeddingModel;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _modelController.dispose();
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _embeddingModelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = _settings.copyWith(
      model: _modelController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      embeddingModel: _embeddingModelController.text.trim().isEmpty
          ? defaultEmbeddingModel
          : _embeddingModelController.text.trim(),
    );
    await widget.repository.save(settings);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).settingsSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final needsApiKey = _settings.requiresApiKey;
    final isOllama = _settings.provider == LlmProviderKind.ollama;
    final supportsBaseUrl =
        isOllama || _settings.provider == LlmProviderKind.openAi;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.llmSettings),
        actions: [
          IconButton(
              onPressed: _save,
              icon: const Icon(Icons.check),
              tooltip: l10n.commonSave),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 760,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DropdownButtonFormField<LlmProviderKind>(
                value: _settings.provider,
                decoration: InputDecoration(labelText: l10n.llmProvider),
                items: LlmProviderKind.values
                    .map((kind) => DropdownMenuItem(
                        value: kind, child: Text(_label(l10n, kind))))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(
                      () => _settings = _settings.copyWith(provider: value));
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _modelController,
                decoration: InputDecoration(labelText: l10n.llmModel),
              ),
              if (needsApiKey) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKeyController,
                  decoration: InputDecoration(labelText: l10n.llmApiKey),
                  obscureText: true,
                ),
              ],
              if (supportsBaseUrl) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _baseUrlController,
                  decoration: InputDecoration(
                    labelText: l10n.llmBaseUrl,
                    hintText:
                        isOllama ? defaultOllamaBaseUrl : defaultOpenAiBaseUrl,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _embeddingModelController,
                decoration: InputDecoration(
                  labelText: l10n.embeddingModel,
                  hintText: defaultEmbeddingModel,
                  helperText: l10n.embeddingModelHint,
                  helperMaxLines: 2,
                ),
              ),
              if (!isOllama) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<ReasoningEffort>(
                  value: _settings.reasoningEffort,
                  decoration: InputDecoration(
                    labelText: l10n.llmReasoningMode,
                    helperText: l10n.llmReasoningHint,
                    helperMaxLines: 2,
                  ),
                  items: ReasoningEffort.values
                      .map((effort) => DropdownMenuItem(
                          value: effort,
                          child: Text(_effortLabel(l10n, effort))))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() =>
                        _settings = _settings.copyWith(reasoningEffort: value));
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _label(AppLocalizations l10n, LlmProviderKind provider) {
    switch (provider) {
      case LlmProviderKind.ollama:
        return l10n.providerOllama;
      case LlmProviderKind.anthropic:
        return l10n.providerAnthropic;
      case LlmProviderKind.openAi:
        return l10n.providerOpenAi;
      case LlmProviderKind.gemini:
        return l10n.providerGemini;
    }
  }

  String _effortLabel(AppLocalizations l10n, ReasoningEffort effort) {
    switch (effort) {
      case ReasoningEffort.fast:
        return l10n.reasoningFast;
      case ReasoningEffort.balanced:
        return l10n.reasoningBalanced;
      case ReasoningEffort.thinking:
        return l10n.reasoningExtraThinking;
    }
  }
}
