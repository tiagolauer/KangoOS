import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kangoos_app/home/relative_time.dart';

void main() {
  final now = DateTime(2026, 7, 22, 14, 30);
  late AppLocalizations en;
  late AppLocalizations pt;

  setUpAll(() async {
    await initializeDateFormatting();
    en = await AppLocalizations.delegate.load(const Locale('en'));
    pt = await AppLocalizations.delegate.load(const Locale('pt'));
  });

  group('formatDayHeader', () {
    test('today', () {
      expect(formatDayHeader(en, DateTime(2026, 7, 22, 9), now: now), 'Today');
      expect(formatDayHeader(pt, DateTime(2026, 7, 22, 9), now: now), 'Hoje');
    });

    test('yesterday', () {
      expect(
          formatDayHeader(en, DateTime(2026, 7, 21, 9), now: now), 'Yesterday');
      expect(formatDayHeader(pt, DateTime(2026, 7, 21, 9), now: now), 'Ontem');
    });

    test('within the last week uses the localized weekday name', () {
      expect(formatDayHeader(en, DateTime(2026, 7, 19), now: now), 'Sunday');
      expect(formatDayHeader(pt, DateTime(2026, 7, 19), now: now),
          startsWith('domingo'));
    });

    test('older than a week uses a localized month/day label', () {
      expect(formatDayHeader(en, DateTime(2026, 7, 10), now: now), 'Jul 10');
      expect(formatDayHeader(pt, DateTime(2026, 7, 10), now: now),
          contains('10'));
    });
  });

  group('formatRelativeTime', () {
    test('under a minute', () {
      expect(
          formatRelativeTime(en, now.subtract(const Duration(seconds: 20)),
              now: now),
          'now');
      expect(
          formatRelativeTime(pt, now.subtract(const Duration(seconds: 20)),
              now: now),
          'agora');
    });

    test('minutes, hours and days', () {
      expect(
          formatRelativeTime(en, now.subtract(const Duration(minutes: 5)),
              now: now),
          '5m ago');
      expect(
          formatRelativeTime(en, now.subtract(const Duration(hours: 3)),
              now: now),
          '3h ago');
      expect(
          formatRelativeTime(en, now.subtract(const Duration(days: 2)),
              now: now),
          '2d ago');
      expect(
          formatRelativeTime(pt, now.subtract(const Duration(minutes: 5)),
              now: now),
          'há 5min');
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
