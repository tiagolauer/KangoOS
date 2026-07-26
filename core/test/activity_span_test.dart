import 'package:kangoos_core/kangoos_core.dart';
import 'package:test/test.dart';

Activity _activity(int id, DateTime capturedAt) => Activity(
      id: id,
      appName: 'code.exe',
      windowTitle: 'window $id',
      capturedAt: capturedAt,
    );

void main() {
  test('a span lasts until the next captured window', () {
    final start = DateTime.utc(2026, 1, 1, 9);
    final spans = activitySpans(
      [
        _activity(1, start),
        _activity(2, start.add(const Duration(minutes: 3))),
      ],
      until: start.add(const Duration(minutes: 4)),
    );

    expect(spans.first.duration, const Duration(minutes: 3));
    expect(spans.last.duration, const Duration(minutes: 1));
  });

  test('a gap longer than the cap counts as idle after the cap', () {
    final start = DateTime.utc(2026, 1, 1, 9);
    final spans = activitySpans(
      [
        _activity(1, start),
        _activity(2, start.add(const Duration(hours: 3))),
      ],
      until: start.add(const Duration(hours: 3, minutes: 1)),
      gapCap: const Duration(minutes: 10),
    );

    expect(spans.first.duration, const Duration(minutes: 10));
  });

  test('durations read as short strings', () {
    expect(formatActivityDuration(const Duration(seconds: 40)), '40s');
    expect(formatActivityDuration(const Duration(minutes: 12)), '12m');
    expect(formatActivityDuration(const Duration(hours: 2)), '2h');
    expect(
        formatActivityDuration(const Duration(hours: 1, minutes: 5)), '1h5m');
  });
}
