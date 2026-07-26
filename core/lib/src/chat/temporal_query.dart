class DateRange {
  const DateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

DateRange parseTemporalRange(String query, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final lower = query.toLowerCase();

  if (lower.contains('yesterday')) {
    return DateRange(today.subtract(const Duration(days: 1)), today);
  }
  if (lower.contains('last week')) {
    final startOfThisWeek = _startOfWeek(today);
    return DateRange(startOfThisWeek.subtract(const Duration(days: 7)), startOfThisWeek);
  }
  if (lower.contains('this week') || lower.contains(' week')) {
    return DateRange(_startOfWeek(today), current);
  }
  return DateRange(today, current);
}

DateTime _startOfWeek(DateTime day) =>
    day.subtract(Duration(days: day.weekday - DateTime.monday));
