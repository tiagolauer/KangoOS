import 'package:kangoos_core/kangoos_core.dart';
import 'package:kangoos_core/kangoos_core_storage.dart';
import 'package:test/test.dart';

void main() {
  test('redacts common secrets before an activity is persisted', () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    final memory = MemoryService(
      database: database,
      activities: SqliteActivityRepository(database),
      summaries: SqliteSummaryRepository(database),
    );

    await memory.record(const NewActivity(
      appName: 'terminal',
      windowTitle: 'Deploy API_KEY=super-secret-value',
      capturedClipboard: 'token=github_pat_12345678901234567890',
    ));

    final activity = (await memory.watchRecentActivities().first).single;
    expect(activity.windowTitle, 'Deploy API_KEY=[REDACTED]');
    expect(activity.capturedClipboard, 'token=[REDACTED]');
  });

  test('PII filtering is configurable and off by default', () {
    const value = 'person@example.com';
    expect(const PrivacyFilter().filter(value), value);
    expect(
      const PrivacyFilter(redactPii: true).filter(value),
      redactedValue,
    );
  });

  test('redacts bearer, cloud secrets and Brazilian PII', () {
    const filter = PrivacyFilter(redactPii: true);
    expect(filter.filter('Authorization: Bearer abcdefghijk'),
        'Authorization: Bearer $redactedValue');
    expect(filter.filter('AWS_SECRET_ACCESS_KEY=very-secret-value'),
        'AWS_SECRET_ACCESS_KEY=$redactedValue');
    expect(filter.filter('phone=+55 (11) 91234-5678'), 'phone=$redactedValue');
  });

  test('applies current privacy settings to capture and durable memory',
      () async {
    final database = KangoosDatabase.memory();
    addTearDown(database.close);
    var redactPii = false;
    final memory = MemoryService(
      database: database,
      activities: SqliteActivityRepository(database),
      summaries: SqliteSummaryRepository(database),
      privacyFilterProvider: () async => PrivacyFilter(redactPii: redactPii),
    );

    await memory.record(const NewActivity(
      appName: 'mail',
      windowTitle: 'person@example.com',
    ));
    expect((await memory.watchRecentActivities().first).single.windowTitle,
        'person@example.com');

    redactPii = true;
    await memory.record(const NewActivity(
      appName: 'phone',
      windowTitle: '+55 (11) 91234-5678',
    ));
    expect((await memory.watchRecentActivities().first).first.windowTitle,
        redactedValue);

    final durable = await memory.remember('API_KEY=very-secret-value');
    expect(durable.kind, SummaryKind.durable);
    expect(durable.content, 'API_KEY=$redactedValue');
  });
}
