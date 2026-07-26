import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';

String formatRelativeTime(AppLocalizations l10n, DateTime dateTime,
    {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(dateTime);
  if (diff.inMinutes < 1) return l10n.timeNow;
  if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
  return l10n.timeDaysAgo(diff.inDays);
}

String formatClockTime(AppLocalizations l10n, DateTime dateTime) =>
    DateFormat.Hm(l10n.localeName).format(dateTime.toLocal());

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

const _daysInAWeek = 7;

String formatDayHeader(AppLocalizations l10n, DateTime day, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final diff = today.difference(dateOnly(day)).inDays;
  if (diff == 0) return l10n.dayToday;
  if (diff == 1) return l10n.dayYesterday;
  if (diff > 1 && diff < _daysInAWeek) {
    return DateFormat.EEEE(l10n.localeName).format(day);
  }
  return DateFormat.MMMd(l10n.localeName).format(day);
}

List<Object> groupByDay<T extends Object>(
    Iterable<T> items, DateTime Function(T) dateOf) {
  final result = <Object>[];
  DateTime? lastDay;
  for (final item in items) {
    final day = dateOnly(dateOf(item));
    if (day != lastDay) {
      result.add(day);
      lastDay = day;
    }
    result.add(item);
  }
  return result;
}
