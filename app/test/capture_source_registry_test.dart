import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_app/capture/capture_source_registry.dart';
import 'package:kangoos_app/capture/window_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('new sources are disabled until explicitly enabled', () async {
    final registry = CaptureSourceRegistry();

    final source = await registry.observe(
      const WindowSnapshot(
        appId: 'windows:c:/apps/code.exe',
        appName: 'code.exe',
        windowTitle: 'main.dart',
      ),
    );

    expect(source.enabled, isFalse);
    expect(source.blocked, isFalse);
    expect(source.lastCapturedAt, isNull);
    expect(source.modalities, isEmpty);
  });

  test('source policy and observed modalities survive a restart', () async {
    final capturedAt = DateTime.utc(2026, 8, 26, 10);
    final registry = CaptureSourceRegistry();
    await registry.observe(
      const WindowSnapshot(
        appId: 'windows:c:/apps/code.exe',
        appName: 'code.exe',
        windowTitle: 'main.dart',
      ),
    );
    await registry.setEnabled('windows:c:/apps/code.exe', true);
    await registry.markCaptured('windows:c:/apps/code.exe', capturedAt, const {
      CaptureModality.metadata,
      CaptureModality.clipboard,
    });

    final restored = (await CaptureSourceRegistry().list()).single;

    expect(restored.canCapture, isTrue);
    expect(restored.lastCapturedAt, capturedAt.toLocal());
    expect(restored.modalities, {
      CaptureModality.metadata,
      CaptureModality.clipboard,
    });
  });

  test('blocking a source overrides its enabled state', () async {
    final registry = CaptureSourceRegistry();
    await registry.observe(
      const WindowSnapshot(
        appId: 'windows:c:/apps/vault.exe',
        appName: 'vault.exe',
        windowTitle: 'Vault',
      ),
    );
    await registry.setEnabled('windows:c:/apps/vault.exe', true);
    await registry.setBlocked('windows:c:/apps/vault.exe', true);

    expect((await registry.list()).single.canCapture, isFalse);
  });

  test('an older completion never replaces the latest capture time', () async {
    final registry = CaptureSourceRegistry();
    await registry.observe(
      const WindowSnapshot(appName: 'code.exe', windowTitle: 'main.dart'),
    );
    final latest = DateTime.utc(2026, 8, 26, 12);
    await registry.markCaptured('code.exe', latest, const {
      CaptureModality.metadata,
    });
    await registry.markCaptured(
      'code.exe',
      latest.subtract(const Duration(seconds: 10)),
      const {CaptureModality.audio},
    );

    final source = (await registry.list()).single;
    expect(source.lastCapturedAt, latest.toLocal());
    expect(source.modalities, {
      CaptureModality.metadata,
      CaptureModality.audio,
    });
  });
}
