import 'package:flutter_test/flutter_test.dart';
import 'package:kangoos_core/kangoos_core.dart';

import 'package:kangoos_app/home/activity_sparkline.dart';

Activity _activity(int id, DateTime capturedAt) => Activity(
      id: id,
      appName: 'code.exe',
      windowTitle: 'window $id',
      capturedAt: capturedAt,
    );

void main() {
  test('an hour of focus counts as minutes, not as switches', () {
    final now = DateTime(2026, 1, 1, 10, 12);
    final focused = bucketActivityMinutesByHour(
      [_activity(1, DateTime(2026, 1, 1, 9))],
      now: now,
    );
    final switching = bucketActivityMinutesByHour(
      [
        for (var i = 0; i < 6; i++)
          _activity(i, DateTime(2026, 1, 1, 10, i * 2)),
      ],
      now: now,
    );

    expect(focused[9], closeTo(10, 0.01));
    expect(switching[10], closeTo(12, 0.01));
  });

  test('a span crossing an hour boundary is split between both hours', () {
    final buckets = bucketActivityMinutesByHour(
      [_activity(1, DateTime(2026, 1, 1, 9, 56))],
      now: DateTime(2026, 1, 1, 10, 30),
    );

    expect(buckets[9], closeTo(4, 0.01));
    expect(buckets[10], closeTo(6, 0.01));
  });

  test('hours with no activity stay at zero', () {
    final buckets = bucketActivityMinutesByHour(
      [_activity(1, DateTime(2026, 1, 1, 9))],
      now: DateTime(2026, 1, 1, 11),
    );

    expect(buckets[8], 0);
    expect(buckets.length, 24);
  });
}
