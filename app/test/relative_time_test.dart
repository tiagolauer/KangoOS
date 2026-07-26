import 'package:kangoos_app/home/relative_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 7, 22, 14, 30);

  group('formatDayHeader', () {
    test('today', () {
      expect(formatDayHeader(DateTime(2026, 7, 22, 9), now: now), 'Today');
    });

    test('yesterday', () {
      expect(formatDayHeader(DateTime(2026, 7, 21, 9), now: now), 'Yesterday');
    });

    test('within the last week uses the weekday name', () {
      expect(formatDayHeader(DateTime(2026, 7, 19), now: now), 'Sunday');
    });

    test('older than a week uses a month/day label', () {
      expect(formatDayHeader(DateTime(2026, 7, 10), now: now), 'Jul 10');
    });
  });

  group('groupByDay', () {
    test('inserts one day marker per distinct day, item order preserved', () {
      final items = [
        DateTime(2026, 7, 22, 10),
        DateTime(2026, 7, 22, 9),
        DateTime(2026, 7, 21, 18),
      ];
      final grouped = groupByDay(items, (d) => d);

      expect(grouped, [
        DateTime(2026, 7, 22),
        items[0],
        items[1],
        DateTime(2026, 7, 21),
        items[2],
      ]);
    });

    test('empty input produces no markers', () {
      expect(groupByDay<DateTime>(const [], (d) => d), isEmpty);
    });
  });
}
