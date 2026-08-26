import 'package:flutter/material.dart';

import '../capture/capture_settings_repository.dart';
import '../theme/kangoos_theme.dart';

class TrayPanel extends StatefulWidget {
  const TrayPanel({
    super.key,
    required this.captureSettingsRepository,
    required this.onOpen,
    required this.onHide,
    required this.onToggleCapture,
    required this.onQuickCapture,
    required this.onQuit,
  });

  final CaptureSettingsRepository captureSettingsRepository;
  final Future<void> Function() onOpen;
  final Future<void> Function() onHide;
  final Future<void> Function() onToggleCapture;
  final Future<bool> Function() onQuickCapture;
  final Future<void> Function() onQuit;

  @override
  State<TrayPanel> createState() => _TrayPanelState();
}

class _TrayPanelState extends State<TrayPanel> {
  CaptureSettings? _settings;
  String? _feedback;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await widget.captureSettingsRepository.load();
    if (mounted) setState(() => _settings = settings);
  }

  Future<void> _toggleCapture() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onToggleCapture();
      await _loadSettings();
      if (mounted) setState(() => _feedback = null);
    } catch (_) {
      if (mounted) {
        setState(() => _feedback = 'Não foi possível alterar a captura.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _quickCapture() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final saved = await widget.onQuickCapture();
      if (mounted) {
        setState(() => _feedback = saved
            ? 'Snippet salvo a partir da área de transferência.'
            : 'A área de transferência não contém texto.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _feedback = 'Não foi possível salvar o snippet.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statusColors = theme.extension<KangoosStatusColors>()!;
    final settings = _settings;
    final active = settings != null && !settings.paused;

    return Scaffold(
      backgroundColor: colors.surface,
      body: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colors.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      'K',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('KangoOS', style: theme.textTheme.titleMedium),
                        Text(
                          'Memória local • respostas em PT-BR',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onHide,
                    icon: const Icon(Icons.close),
                    tooltip: 'Fechar painel',
                  ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 18, bottom: 8),
                  children: [
                    _TrayAction(
                      icon: Icons.open_in_new,
                      title: 'Abrir KangoOS',
                      subtitle: 'Voltar para a janela principal',
                      foreground: colors.onPrimary,
                      background: colors.primary,
                      onTap: _busy ? null : widget.onOpen,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        border: Border.all(color: colors.outline),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CAPTURA LOCAL',
                              style: theme.textTheme.labelSmall),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: active
                                      ? statusColors.done
                                      : colors.secondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  settings == null
                                      ? 'Carregando…'
                                      : active
                                          ? 'Captura ativa'
                                          : 'Captura pausada',
                                  style: theme.textTheme.labelLarge,
                                ),
                              ),
                              Switch(
                                value: active,
                                onChanged: settings == null || _busy
                                    ? null
                                    : (_) => _toggleCapture(),
                              ),
                            ],
                          ),
                          Text(
                            'A atividade permanece neste dispositivo e alimenta sua memória de trabalho.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _TrayAction(
                      icon: Icons.content_paste_go_outlined,
                      title: 'Salvar área de transferência',
                      subtitle: 'Criar um snippet com o texto copiado',
                      onTap: _busy ? null : _quickCapture,
                    ),
                    if (_feedback case final feedback?) ...[
                      const SizedBox(height: 10),
                      Text(
                        feedback,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Divider(color: colors.outline),
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: colors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'KangoOS continua ativo na bandeja',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : widget.onQuit,
                    icon: const Icon(Icons.power_settings_new),
                    tooltip: 'Sair do KangoOS',
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

class _TrayAction extends StatelessWidget {
  const _TrayAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.foreground,
    this.background,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function()? onTap;
  final Color? foreground;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final contentColor = foreground ?? colors.onSurface;

    return Semantics(
      button: true,
      child: Material(
        color: background ?? colors.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: background ?? colors.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: contentColor, size: 21),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: contentColor,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: contentColor.withValues(alpha: 0.72),
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: contentColor, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
