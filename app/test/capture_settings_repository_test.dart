import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_app/capture/capture_settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('timed pause persists across repository instances', () async {
    final resumeAt = DateTime.now().add(const Duration(hours: 1));
    await CaptureSettingsRepository().save(
      CaptureSettings(paused: true, resumeAt: resumeAt),
    );

    final restored = await CaptureSettingsRepository().load();

    expect(restored.paused, isTrue);
    expect(restored.resumeAt, resumeAt);
  });

  test('expired timed pause resumes and clears its deadline', () async {
    await CaptureSettingsRepository().save(
      CaptureSettings(
        paused: true,
        resumeAt: DateTime.now().subtract(const Duration(seconds: 1)),
      ),
    );

    final restored = await CaptureSettingsRepository().load();
    final persisted = await CaptureSettingsRepository().load();

    expect(restored.paused, isFalse);
    expect(restored.resumeAt, isNull);
    expect(persisted.paused, isFalse);
    expect(persisted.resumeAt, isNull);
  });

  test('resuming manually clears a stale deadline', () async {
    final repository = CaptureSettingsRepository();
    await repository.save(
      CaptureSettings(
        paused: true,
        resumeAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    await repository.save(const CaptureSettings(paused: false));

    final restored = await repository.load();

    expect(restored.paused, isFalse);
    expect(restored.resumeAt, isNull);
  });
}
