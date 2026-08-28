import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:kangoos_core/kangoos_core.dart';
import 'package:path/path.dart' as p;

import '../confirm_dialog.dart';
import 'browser_profile_discovery.dart';
import 'connector_credentials.dart';
import 'connector_runtime.dart';

const _calendarSourceId = 'calendar:primary';
const _webSourceId = 'web:searxng';

class ConnectorSettingsScreen extends StatefulWidget {
  const ConnectorSettingsScreen({
    super.key,
    required this.repository,
    required this.credentials,
    required this.persona,
    required this.conversationId,
    this.browserDiscovery,
  });

  final ConnectorRepository repository;
  final ConnectorCredentials credentials;
  final PersonaService persona;
  final int conversationId;
  final BrowserProfileDiscovery? browserDiscovery;

  @override
  State<ConnectorSettingsScreen> createState() =>
      _ConnectorSettingsScreenState();
}

class _ConnectorSettingsScreenState extends State<ConnectorSettingsScreen> {
  final _calendarUrl = TextEditingController();
  final _calendarUsername = TextEditingController();
  final _calendarPassword = TextEditingController();
  final _webUrl = TextEditingController();
  var _sources = <ConnectorSource>[];
  var _profiles = <BrowserProfile>[];
  var _grants = <String>{};
  LocalPersona? _persona;
  var _calendarPasswordStored = false;
  var _loading = true;

  BrowserProfileDiscovery get _discovery =>
      widget.browserDiscovery ?? BrowserProfileDiscovery();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _calendarUrl.dispose();
    _calendarUsername.dispose();
    _calendarPassword.dispose();
    _webUrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final sources = await widget.repository.sources();
      final permissions = await widget.repository.permissionsForConversation(
        widget.conversationId,
      );
      final credentials = await widget.credentials.loadCalendar();
      final persona = await widget.persona.load();
      final profiles = await _discovery.discover();
      if (!mounted) return;
      final calendar = _source(sources, ConnectorSourceKind.calendar);
      final web = _source(sources, ConnectorSourceKind.web);
      setState(() {
        _sources = sources;
        _profiles = profiles;
        _grants =
            permissions
                .where(
                  (permission) =>
                      permission.surface == ConnectorSurface.desktop,
                )
                .map(
                  (permission) =>
                      _grantKey(permission.toolName, permission.access),
                )
                .toSet();
        _persona = persona;
        _calendarUrl.text = calendar?.location ?? '';
        _calendarUsername.text = credentials.username;
        _calendarPassword.clear();
        _calendarPasswordStored = credentials.isComplete;
        _webUrl.text = web?.location ?? '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(error);
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Não foi possível salvar: $error')));
  }

  Future<void> _addFolder() async {
    final path = await getDirectoryPath(
      confirmButtonText: 'Permitir esta pasta',
    );
    if (path == null) return;
    await _perform(
      () => widget.repository.upsertSource(
        ConnectorSourceInput(
          id: 'file:${DateTime.now().microsecondsSinceEpoch}',
          kind: ConnectorSourceKind.file,
          label: p.basename(path),
          location: path,
        ),
      ),
    );
  }

  Future<void> _toggleSource(ConnectorSource source, bool enabled) => _perform(
    () => widget.repository.upsertSource(
      ConnectorSourceInput(
        id: source.id,
        kind: source.kind,
        label: source.label,
        location: source.location,
        enabled: enabled,
      ),
    ),
  );

  Future<void> _deleteSource(ConnectorSource source) async {
    final confirmed = await confirmDestructiveAction(
      context: context,
      title: 'Remover conector?',
      body: 'O KangoOS perderá o acesso a “${source.label}” imediatamente.',
      confirmLabel: 'Remover',
    );
    if (!confirmed) return;
    await _perform(() async {
      await widget.repository.deleteSource(source.id);
      if (source.kind == ConnectorSourceKind.calendar) {
        await widget.credentials.deleteCalendar();
      }
    });
  }

  Future<void> _toggleBrowser(BrowserProfile profile, bool selected) =>
      _perform(() async {
        if (!selected) {
          await widget.repository.deleteSource(profile.id);
          return;
        }
        await widget.repository.upsertSource(
          ConnectorSourceInput(
            id: profile.id,
            kind: ConnectorSourceKind.browser,
            label: profile.name,
            location: BrowserProfileDiscovery.encode(profile),
          ),
        );
      });

  Future<void> _saveCalendar() => _perform(() async {
    final url = _validHttpUrl(
      _calendarUrl.text,
      'calendário',
      requireSecure: true,
    );
    final username = _calendarUsername.text.trim();
    final typedPassword = _calendarPassword.text;
    final current = await widget.credentials.loadCalendar();
    final password = typedPassword.isEmpty ? current.password : typedPassword;
    final credentials = CalendarCredentials(
      username: username,
      password: password,
    );
    await widget.credentials.saveCalendar(credentials);
    await widget.repository.upsertSource(
      ConnectorSourceInput(
        id: _calendarSourceId,
        kind: ConnectorSourceKind.calendar,
        label: 'Calendário CalDAV',
        location: url.toString(),
      ),
    );
  });

  Future<void> _saveWeb() => _perform(() async {
    final url = _validHttpUrl(_webUrl.text, 'SearXNG', requireSecure: true);
    await widget.repository.upsertSource(
      ConnectorSourceInput(
        id: _webSourceId,
        kind: ConnectorSourceKind.web,
        label: 'Pesquisa web SearXNG',
        location: url.toString(),
      ),
    );
  });

  Future<void> _toggleGrant(ConnectorPermissionOption option, bool enabled) =>
      _perform(() async {
        if (enabled) {
          await widget.repository.grantTool(
            surface: ConnectorSurface.desktop,
            conversationId: widget.conversationId,
            toolName: option.name,
            access: option.access,
          );
          return;
        }
        await widget.repository.revokeTool(
          surface: ConnectorSurface.desktop,
          conversationId: widget.conversationId,
          toolName: option.name,
          access: option.access,
        );
      });

  Future<void> _generatePersona() => _perform(() async {
    final generated = await widget.persona.generate();
    if (generated == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ainda não há memórias recorrentes suficientes.'),
        ),
      );
    }
  });

  Future<void> _editPersona() async {
    final persona = _persona;
    if (persona == null) return;
    final controller = TextEditingController(text: persona.content);
    final content = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Editar persona local'),
            content: SizedBox(
              width: 560,
              child: TextField(
                controller: controller,
                maxLines: 12,
                maxLength: maxLocalPersonaCharacters,
                decoration: const InputDecoration(
                  helperText:
                      'Preferências derivadas das suas memórias recorrentes.',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Salvar'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (content != null) await _perform(() => widget.persona.edit(content));
  }

  Future<void> _deletePersona() async {
    final confirmed = await confirmDestructiveAction(
      context: context,
      title: 'Excluir persona local?',
      body:
          'O conteúdo derivado será apagado por completo. Suas memórias de origem não serão removidas.',
      confirmLabel: 'Excluir persona',
    );
    if (confirmed) await _perform(() async => widget.persona.delete());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conectores e permissões')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _privacyBanner(context),
                      const SizedBox(height: 18),
                      _filesCard(),
                      const SizedBox(height: 14),
                      _browserCard(),
                      const SizedBox(height: 14),
                      _calendarCard(),
                      const SizedBox(height: 14),
                      _webCard(),
                      const SizedBox(height: 14),
                      _personaCard(),
                      const SizedBox(height: 14),
                      _permissionsCard(),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _privacyBanner(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Tudo começa bloqueado. Você escolhe as fontes e libera cada ferramenta por conversa. Escritas no calendário e pesquisas externas sempre pedem confirmação.',
          ),
        ),
      ],
    ),
  );

  Widget _filesCard() {
    final files =
        _sources
            .where((source) => source.kind == ConnectorSourceKind.file)
            .toList();
    return _section(
      icon: Icons.folder_outlined,
      title: 'Arquivos locais',
      subtitle:
          'Somente pastas permitidas. Binários e arquivos acima de 1 MB são recusados.',
      children: [
        for (final source in files) _sourceTile(source),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _addFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Permitir pasta'),
          ),
        ),
      ],
    );
  }

  Widget _browserCard() {
    final selected = {
      for (final source in _sources.where(
        (source) => source.kind == ConnectorSourceKind.browser,
      ))
        source.id: source,
    };
    final discoveredIds = _profiles.map((profile) => profile.id).toSet();
    final missing =
        selected.values
            .where((source) => !discoveredIds.contains(source.id))
            .toList();
    return _section(
      icon: Icons.travel_explore_outlined,
      title: 'Navegadores',
      subtitle:
          'Histórico e favoritos ficam separados por perfil. Selecione cada perfil explicitamente.',
      children: [
        if (_profiles.isEmpty)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Nenhum perfil compatível encontrado.'),
          ),
        for (final profile in _profiles)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: selected[profile.id]?.enabled ?? false,
            title: Text(profile.name),
            subtitle: Text(
              profile.path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onChanged: (value) => _toggleBrowser(profile, value ?? false),
          ),
        for (final source in missing) _sourceTile(source),
      ],
    );
  }

  Widget _calendarCard() {
    final source = _source(_sources, ConnectorSourceKind.calendar);
    return _section(
      icon: Icons.calendar_month_outlined,
      title: 'Calendário CalDAV',
      subtitle:
          'Leitura por permissão. Criar, editar e excluir exigem confirmação em cada ação.',
      children: [
        if (source?.enabled == true && !_calendarPasswordStored) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.key_off_outlined),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Conector pausado: as credenciais protegidas estão ausentes. Informe usuário e senha e salve novamente.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _calendarUrl,
          decoration: const InputDecoration(
            labelText: 'URL do calendário',
            hintText: 'https://servidor/caldav/usuario/calendario/',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _calendarUsername,
          decoration: const InputDecoration(labelText: 'Usuário'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _calendarPassword,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Senha ou senha de app',
            hintText:
                _calendarPasswordStored ? 'Credencial já protegida' : null,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(onPressed: _saveCalendar, child: const Text('Salvar')),
            if (source != null)
              OutlinedButton(
                onPressed: () => _toggleSource(source, !source.enabled),
                child: Text(source.enabled ? 'Desativar' : 'Ativar'),
              ),
            if (source != null)
              TextButton(
                onPressed: () => _deleteSource(source),
                child: const Text('Remover'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _webCard() {
    final source = _source(_sources, ConnectorSourceKind.web);
    return _section(
      icon: Icons.public_outlined,
      title: 'Pesquisa web opcional',
      subtitle:
          'Usa um endpoint SearXNG escolhido por você. A consulta só sai do computador após consentimento.',
      children: [
        TextField(
          controller: _webUrl,
          decoration: const InputDecoration(
            labelText: 'Endpoint SearXNG',
            hintText: 'https://searx.exemplo/search',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(onPressed: _saveWeb, child: const Text('Salvar')),
            if (source != null)
              OutlinedButton(
                onPressed: () => _toggleSource(source, !source.enabled),
                child: Text(source.enabled ? 'Desativar' : 'Ativar'),
              ),
            if (source != null)
              TextButton(
                onPressed: () => _deleteSource(source),
                child: const Text('Remover'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _personaCard() {
    final persona = _persona;
    return _section(
      icon: Icons.person_outline,
      title: 'Persona local',
      subtitle:
          'Derivada apenas de padrões recorrentes da sua memória. Você pode editar, desligar ou apagar tudo.',
      children: [
        if (persona == null)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _generatePersona,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Gerar das memórias recorrentes'),
            ),
          )
        else ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: persona.enabled,
            title: Text(
              persona.enabled ? 'Persona ativa' : 'Persona desativada',
            ),
            onChanged:
                (value) => _perform(() => widget.persona.setEnabled(value)),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(persona.content),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: _editPersona,
                child: const Text('Editar'),
              ),
              TextButton(
                onPressed: _deletePersona,
                child: const Text('Excluir por completo'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _permissionsCard() => _section(
    icon: Icons.admin_panel_settings_outlined,
    title: 'Permissões desta conversa',
    subtitle:
        'Conversa #${widget.conversationId}. Uma permissão não ativa uma fonte desativada.',
    children: [
      for (final option in connectorPermissionOptions)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _grants.contains(_grantKey(option.name, option.access)),
          title: Text(option.label),
          subtitle: Text(switch (option.access) {
            ConnectorAccess.read => 'Leitura local',
            ConnectorAccess.write => 'Escrita com confirmação',
            ConnectorAccess.external => 'Envio externo com consentimento',
          }),
          onChanged: (value) => _toggleGrant(option, value),
        ),
    ],
  );

  Widget _sourceTile(ConnectorSource source) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    value: source.enabled,
    title: Text(source.label),
    subtitle: Text(
      source.location,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    onChanged: (value) => _toggleSource(source, value),
    secondary: IconButton(
      tooltip: 'Remover',
      onPressed: () => _deleteSource(source),
      icon: const Icon(Icons.delete_outline),
    ),
  );

  Widget _section({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}

ConnectorSource? _source(
  List<ConnectorSource> sources,
  ConnectorSourceKind kind,
) {
  for (final source in sources) {
    if (source.kind == kind) return source;
  }
  return null;
}

String _grantKey(String toolName, ConnectorAccess access) =>
    '$toolName:${access.name}';

Uri _validHttpUrl(String value, String label, {bool requireSecure = false}) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (requireSecure && uri.scheme != 'https' && !_isLoopback(uri.host))) {
    throw FormatException('URL de $label inválida.');
  }
  return uri;
}

bool _isLoopback(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1';
}
