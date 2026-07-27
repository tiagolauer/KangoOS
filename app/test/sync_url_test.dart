import 'package:flutter_test/flutter_test.dart';

import 'package:kangoos_app/sync/sync_url.dart';

void main() {
  test('https to any host is usable', () {
    expect(checkSyncUrl('https://kango.example.com'), isA<SyncUrlUsable>());
  });

  test('http to a loopback host is usable', () {
    for (final url in [
      'http://localhost:8080',
      'http://127.0.0.1:8080',
      'http://kango.localhost:8080',
    ]) {
      expect(checkSyncUrl(url), isA<SyncUrlUsable>(), reason: url);
    }
  });

  test('http to a remote host needs confirmation', () {
    final check = checkSyncUrl('http://nas.local:8080');

    expect(check, isA<SyncUrlInsecure>());
    expect((check as SyncUrlInsecure).uri.host, 'nas.local');
  });

  test('garbage is rejected instead of reaching the sync client', () {
    expect(
      (checkSyncUrl('not a url') as SyncUrlRejected).problem,
      SyncUrlProblem.notAUrl,
    );
    expect(
      (checkSyncUrl('kango.example.com') as SyncUrlRejected).problem,
      SyncUrlProblem.notAUrl,
    );
    expect(
      (checkSyncUrl('ftp://kango.example.com') as SyncUrlRejected).problem,
      SyncUrlProblem.unsupportedScheme,
    );
    expect(
      (checkSyncUrl('   ') as SyncUrlRejected).problem,
      SyncUrlProblem.empty,
    );
  });
}
