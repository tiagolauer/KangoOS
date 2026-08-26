import 'package:kangoos_core/kangoos_core.dart';

import 'browser_profile_discovery.dart';
import 'connector_credentials.dart';

typedef ConnectorPermissionOption =
    ({String name, ConnectorAccess access, String label});

const connectorPermissionOptions = <ConnectorPermissionOption>[
  (
    name: searchLocalFilesToolName,
    access: ConnectorAccess.read,
    label: 'Buscar arquivos locais',
  ),
  (
    name: readLocalFileToolName,
    access: ConnectorAccess.read,
    label: 'Ler arquivos locais',
  ),
  (
    name: searchBrowserToolName,
    access: ConnectorAccess.read,
    label: 'Consultar histórico e favoritos',
  ),
  (
    name: searchCalendarEventsToolName,
    access: ConnectorAccess.read,
    label: 'Buscar eventos do calendário',
  ),
  (
    name: getCalendarEventToolName,
    access: ConnectorAccess.read,
    label: 'Ler evento do calendário',
  ),
  (
    name: createCalendarEventToolName,
    access: ConnectorAccess.write,
    label: 'Criar evento após confirmação',
  ),
  (
    name: updateCalendarEventToolName,
    access: ConnectorAccess.write,
    label: 'Editar evento após confirmação',
  ),
  (
    name: deleteCalendarEventToolName,
    access: ConnectorAccess.write,
    label: 'Excluir evento após confirmação',
  ),
  (
    name: 'search_web',
    access: ConnectorAccess.external,
    label: 'Pesquisar na web após consentimento',
  ),
];

class ConnectorRuntime {
  const ConnectorRuntime({required this.repository, required this.credentials});

  final ConnectorRepository repository;
  final ConnectorCredentials credentials;

  Future<ConnectorSession> open() async {
    final sources = await repository.sources(enabled: true);
    final tools = <AgentConnectorTool>[];
    final closers = <void Function()>[];
    final sourceBindings = <String, ConnectorSource>{};
    if (sources.any((source) => source.kind == ConnectorSourceKind.file)) {
      tools.addAll(
        LocalFileConnector(
          rootsProvider:
              () async => (await repository.sources(enabled: true))
                  .where((source) => source.kind == ConnectorSourceKind.file)
                  .map(
                    (source) =>
                        LocalFileRoot(id: source.id, path: source.location),
                  )
                  .toList(growable: false),
        ).tools,
      );
    }
    if (sources.any((source) => source.kind == ConnectorSourceKind.browser)) {
      tools.addAll(
        BrowserConnector(
          profilesProvider:
              () async => (await repository.sources(enabled: true))
                  .where((source) => source.kind == ConnectorSourceKind.browser)
                  .map(
                    (source) => BrowserProfileDiscovery.decode(
                      source.id,
                      source.location,
                    ),
                  )
                  .toList(growable: false),
        ).tools,
      );
    }
    final calendar = _first(sources, ConnectorSourceKind.calendar);
    if (calendar != null) {
      final calendarCredentials = await credentials.loadCalendar();
      if (calendarCredentials.isComplete) {
        final connector = CalDavConnector(
          calendarUri: _httpUri(
            calendar.location,
            'calendário',
            requireSecure: true,
          ),
          username: calendarCredentials.username,
          password: calendarCredentials.password,
        );
        tools.addAll(connector.tools);
        for (final tool in connector.tools) {
          sourceBindings[tool.definition.name] = calendar;
        }
        closers.add(connector.close);
      }
    }
    final web = _first(sources, ConnectorSourceKind.web);
    if (web != null) {
      final connector = SearxngConnector(
        endpoint: _httpUri(web.location, 'SearXNG', requireSecure: true),
      );
      tools.add(connector);
      sourceBindings[connector.definition.name] = web;
      closers.add(connector.close);
    }
    return ConnectorSession(
      registry: AgentConnectorRegistry(tools),
      permissionChecker:
          (toolName, access, surface, conversationId) => _isAllowed(
            toolName,
            access,
            surface,
            conversationId,
            sourceBindings,
          ),
      close: () {
        for (final close in closers) {
          close();
        }
      },
    );
  }

  Future<bool> _isAllowed(
    String toolName,
    ConnectorAccess access,
    ConnectorSurface surface,
    int? conversationId,
    Map<String, ConnectorSource> sourceBindings,
  ) async {
    final kind = _kindForTool(toolName);
    if (kind == null) return false;
    final boundSource = sourceBindings[toolName];
    final sourceEnabled =
        boundSource == null
            ? (await repository.sources(
              enabled: true,
            )).any((source) => source.kind == kind)
            : _sameSource(await repository.source(boundSource.id), boundSource);
    if (!sourceEnabled) return false;
    return repository.isToolAllowed(
      surface: surface,
      conversationId: conversationId,
      toolName: toolName,
      access: access,
    );
  }
}

bool _sameSource(ConnectorSource? current, ConnectorSource snapshot) =>
    current != null &&
    current.enabled &&
    current.kind == snapshot.kind &&
    current.location == snapshot.location &&
    current.updatedAt == snapshot.updatedAt;

class ConnectorSession {
  const ConnectorSession({
    required this.registry,
    required this.permissionChecker,
    required this.close,
  });

  final AgentConnectorRegistry registry;
  final ConnectorPermissionChecker permissionChecker;
  final void Function() close;
}

class ConnectorConfigurationException implements Exception {
  const ConnectorConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

ConnectorSource? _first(
  List<ConnectorSource> sources,
  ConnectorSourceKind kind,
) {
  for (final source in sources) {
    if (source.kind == kind) return source;
  }
  return null;
}

ConnectorSourceKind? _kindForTool(String toolName) {
  if (toolName == searchLocalFilesToolName ||
      toolName == readLocalFileToolName) {
    return ConnectorSourceKind.file;
  }
  if (toolName == searchBrowserToolName) return ConnectorSourceKind.browser;
  if (toolName.endsWith('_calendar_event') ||
      toolName.endsWith('_calendar_events')) {
    return ConnectorSourceKind.calendar;
  }
  if (toolName == 'search_web') return ConnectorSourceKind.web;
  return null;
}

Uri _httpUri(String value, String label, {required bool requireSecure}) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (requireSecure && uri.scheme != 'https' && !_isLoopback(uri.host))) {
    throw ConnectorConfigurationException(
      'A URL de $label configurada é inválida.',
    );
  }
  return uri;
}

bool _isLoopback(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized == '127.0.0.1' ||
      normalized == '::1';
}
