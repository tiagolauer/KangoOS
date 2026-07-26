String formatRelativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String formatClockTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String formatDayHeader(DateTime day, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final diff = today.difference(dateOnly(day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return _weekdayNames[day.weekday - 1];
  return '${_monthNames[day.month - 1]} ${day.day}';
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
