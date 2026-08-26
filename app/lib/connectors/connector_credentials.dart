import '../secure_credential_store.dart';

class CalendarCredentials {
  const CalendarCredentials({required this.username, required this.password});

  final String username;
  final String password;

  bool get isComplete => username.isNotEmpty && password.isNotEmpty;
}

class ConnectorCredentials {
  ConnectorCredentials({SecureCredentialStore? secureStore})
    : _secureStore = secureStore ?? const FlutterSecureCredentialStore();

  static const _calendarUsernameKey = 'connector_calendar_username';
  static const _calendarPasswordKey = 'connector_calendar_password';

  final SecureCredentialStore _secureStore;

  Future<CalendarCredentials> loadCalendar() async => CalendarCredentials(
    username: await _secureStore.read(_calendarUsernameKey) ?? '',
    password: await _secureStore.read(_calendarPasswordKey) ?? '',
  );

  Future<void> saveCalendar(CalendarCredentials credentials) async {
    final username = credentials.username.trim();
    if (username.isEmpty || credentials.password.isEmpty) {
      throw ArgumentError('Usuário e senha do calendário são obrigatórios.');
    }
    await _secureStore.write(_calendarUsernameKey, username);
    await _secureStore.write(_calendarPasswordKey, credentials.password);
  }

  Future<void> deleteCalendar() async {
    await _secureStore.delete(_calendarUsernameKey);
    await _secureStore.delete(_calendarPasswordKey);
  }
}
