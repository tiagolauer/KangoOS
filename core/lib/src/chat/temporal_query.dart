class DateRange {
  const DateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

const maxTemporalLookbackDays = 36500;
const approximateRecentPeriod = Duration(days: 7);

enum TemporalRelation { before, during, lastOccurrence }

class TemporalQuery {
  const TemporalQuery({
    this.start,
    this.end,
    required this.fuzzy,
    required this.confidence,
    this.timezoneOffset,
    this.relation,
    this.anchor,
  });

  final DateTime? start;
  final DateTime? end;
  final bool fuzzy;
  final double confidence;
  final Duration? timezoneOffset;
  final TemporalRelation? relation;
  final String? anchor;

  bool get hasRange => start != null && end != null;
}

abstract interface class TemporalParser {
  Future<TemporalQuery> parse(String query, DateTime reference);
}

class RuleBasedTemporalParser implements TemporalParser {
  const RuleBasedTemporalParser();

  @override
  Future<TemporalQuery> parse(String query, DateTime reference) async =>
      parseSync(query, reference);

  TemporalQuery parseSync(String query, DateTime reference) {
    final lower = _normalize(query);
    final timezoneOffset = _timezoneOffset(lower);
    final wallReference =
        timezoneOffset == null
            ? reference
            : reference.toUtc().add(timezoneOffset);
    final today = DateTime(
      wallReference.year,
      wallReference.month,
      wallReference.day,
    );
    DateTime? start;
    DateTime? end;
    var fuzzy = false;
    var confidence = 0.0;

    final explicitDates = _explicitDates(lower);
    final weekdays = _weekdays(lower);
    final relativeDays = _relativeDayCount(lower);
    final recentDays = _recentDayCount(lower);
    final month = _month(lower, wallReference);
    final relation = _relation(lower);

    if (explicitDates.length >= 2 && _isRange(lower)) {
      start = explicitDates.first;
      end = explicitDates[1].add(const Duration(days: 1));
      confidence = 1;
    } else if (weekdays.length >= 2 && _isRange(lower)) {
      start = _previousOrCurrentWeekday(today, weekdays.first);
      final daysForward = (weekdays[1] - start.weekday) % DateTime.daysPerWeek;
      end = start.add(Duration(days: daysForward + 1));
      confidence = 0.9;
    } else if (relativeDays != null) {
      start = today.subtract(Duration(days: relativeDays));
      end = start.add(const Duration(days: 1));
      confidence = 0.95;
    } else if (recentDays != null) {
      start = today.subtract(Duration(days: recentDays - 1));
      end = wallReference;
      confidence = 0.9;
    } else if (_containsAny(lower, const [
      'day before yesterday',
      'anteontem',
    ])) {
      start = today.subtract(const Duration(days: 2));
      end = start.add(const Duration(days: 1));
      confidence = 1;
    } else if (_containsAny(lower, const ['yesterday', 'ontem'])) {
      start = today.subtract(const Duration(days: 1));
      end = today;
      confidence = 1;
    } else if (_containsAny(lower, const [
      'recently',
      'recentemente',
      'ultimamente',
    ])) {
      start = wallReference.subtract(approximateRecentPeriod);
      end = wallReference;
      fuzzy = true;
      confidence = 0.65;
    } else if (_containsAny(lower, const [
      'a few weeks ago',
      'algumas semanas atras',
    ])) {
      start = today.subtract(const Duration(days: 28));
      end = today.subtract(const Duration(days: 14));
      fuzzy = true;
      confidence = 0.55;
    } else if (_containsAny(lower, const ['last week', 'semana passada'])) {
      final currentWeek = _startOfWeek(today);
      start = currentWeek.subtract(const Duration(days: 7));
      end = currentWeek;
      confidence = 1;
    } else if (_containsAny(lower, const ['this week', 'esta semana'])) {
      start = _startOfWeek(today);
      end = wallReference;
      confidence = 1;
    } else if (_containsAny(lower, const ['last month', 'mes passado'])) {
      end = DateTime(today.year, today.month);
      start = DateTime(end.year, end.month - 1);
      confidence = 1;
    } else if (_containsAny(lower, const ['this month', 'este mes'])) {
      start = DateTime(today.year, today.month);
      end = wallReference;
      confidence = 1;
    } else if (_containsAny(lower, const ['today', 'hoje'])) {
      start = today;
      end = wallReference;
      confidence = 1;
    } else if (month != null) {
      final monthStart = DateTime(month.year, month.month);
      final monthEnd = DateTime(month.year, month.month + 1);
      if (_containsAny(lower, const ['end of', 'fim de', 'final de'])) {
        start = monthEnd.subtract(const Duration(days: 7));
        end = monthEnd;
        fuzzy = true;
        confidence = 0.8;
      } else if (_containsAny(lower, const [
        'beginning of',
        'start of',
        'inicio de',
        'comeco de',
      ])) {
        start = monthStart;
        end = monthStart.add(const Duration(days: 7));
        fuzzy = true;
        confidence = 0.8;
      } else {
        start = monthStart;
        end = monthEnd;
        confidence = 0.9;
      }
    } else if (explicitDates.isNotEmpty) {
      start = explicitDates.first;
      end = start.add(const Duration(days: 1));
      confidence = 1;
    } else if (weekdays.isNotEmpty) {
      start =
          _containsAny(lower, const ['last ', ' passada', ' passado'])
              ? _previousWeekday(today, weekdays.first)
              : _previousOrCurrentWeekday(today, weekdays.first);
      end = start.add(const Duration(days: 1));
      fuzzy = _containsAny(lower, const [
        'around',
        'about',
        'por volta',
        'aproximadamente',
      ]);
      confidence = fuzzy ? 0.75 : 0.9;
    }

    if (start != null && end != null && _isWeekPhrase(lower)) {
      final narrowed = _narrowWeek(lower, start, end);
      start = narrowed.start;
      end = narrowed.end;
      fuzzy = narrowed.fuzzy;
      confidence = narrowed.confidence;
    }

    final hour = _hour(lower);
    if (hour != null) {
      final day = start ?? today;
      start = DateTime(
        day.year,
        day.month,
        day.day,
        hour,
      ).subtract(const Duration(hours: 1));
      end = start.add(const Duration(hours: 2));
      fuzzy = true;
      confidence = confidence == 0 ? 0.75 : confidence;
    } else if (start != null &&
        end != null &&
        end.difference(start) <= const Duration(days: 1)) {
      if (_containsAny(lower, const ['morning', 'manha'])) {
        start = DateTime(start.year, start.month, start.day, 6);
        end = DateTime(start.year, start.month, start.day, 12);
        fuzzy = true;
      } else if (_containsAny(lower, const ['afternoon', 'tarde'])) {
        start = DateTime(start.year, start.month, start.day, 12);
        end = DateTime(start.year, start.month, start.day, 18);
        fuzzy = true;
      } else if (_containsAny(lower, const ['evening', 'night', 'noite'])) {
        start = DateTime(start.year, start.month, start.day, 18);
        end = DateTime(start.year, start.month, start.day + 1);
        fuzzy = true;
      }
    }

    final hasRelation = relation != null;
    return TemporalQuery(
      start: _toInstant(start, timezoneOffset, reference.isUtc),
      end: _toInstant(end, timezoneOffset, reference.isUtc),
      fuzzy: fuzzy || hasRelation,
      confidence: confidence == 0 && hasRelation ? 0.65 : confidence,
      timezoneOffset: timezoneOffset,
      relation: relation?.relation,
      anchor: relation?.anchor,
    );
  }
}

DateRange parseTemporalRange(String query, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final parsed = const RuleBasedTemporalParser().parseSync(query, reference);
  final today =
      reference.isUtc
          ? DateTime.utc(reference.year, reference.month, reference.day)
          : DateTime(reference.year, reference.month, reference.day);
  return DateRange(parsed.start ?? today, parsed.end ?? reference);
}

bool _containsAny(String value, List<String> candidates) =>
    candidates.any(value.contains);

bool _isRange(String query) =>
    _containsAny(query, const ['between', 'from', 'entre', 'de ']) &&
    _containsAny(query, const [' and ', ' to ', ' e ', ' a ']);

DateTime _startOfWeek(DateTime day) =>
    day.subtract(Duration(days: day.weekday - DateTime.monday));

List<DateTime> _explicitDates(String query) {
  final matches = <({int index, DateTime date})>[];
  for (final match in RegExp(
    r'\b(\d{4})-(\d{2})-(\d{2})\b',
  ).allMatches(query)) {
    final date = _validDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
    if (date != null) matches.add((index: match.start, date: date));
  }
  for (final match in RegExp(
    r'\b(\d{1,2})/(\d{1,2})/(\d{4})\b',
  ).allMatches(query)) {
    final date = _validDate(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
    );
    if (date != null) matches.add((index: match.start, date: date));
  }
  matches.sort((a, b) => a.index.compareTo(b.index));
  return matches.map((match) => match.date).toList();
}

DateTime? _validDate(int year, int month, int day) {
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

int? _hour(String query) {
  final match = RegExp(
    r'\b(?:around|about|por volta d[ae]s?)?\s*(\d{1,2})(?::\d{2}|h)\b',
  ).firstMatch(query);
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  return hour <= 23 ? hour : null;
}

List<int> _weekdays(String query) {
  const names = {
    'monday': DateTime.monday,
    'segunda': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'terca': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'quarta': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'quinta': DateTime.thursday,
    'friday': DateTime.friday,
    'sexta': DateTime.friday,
    'saturday': DateTime.saturday,
    'sabado': DateTime.saturday,
    'sunday': DateTime.sunday,
    'domingo': DateTime.sunday,
  };
  final matches = <({int index, int weekday})>[];
  for (final entry in names.entries) {
    var offset = 0;
    while (true) {
      final index = query.indexOf(entry.key, offset);
      if (index < 0) break;
      matches.add((index: index, weekday: entry.value));
      offset = index + entry.key.length;
    }
  }
  matches.sort((a, b) => a.index.compareTo(b.index));
  return matches.map((match) => match.weekday).toList();
}

DateTime _previousOrCurrentWeekday(DateTime today, int weekday) {
  final daysBack = (today.weekday - weekday) % DateTime.daysPerWeek;
  return today.subtract(Duration(days: daysBack));
}

DateTime _previousWeekday(DateTime today, int weekday) {
  final daysBack = (today.weekday - weekday) % DateTime.daysPerWeek;
  return today.subtract(Duration(days: daysBack == 0 ? 7 : daysBack));
}

({TemporalRelation relation, String anchor})? _relation(String query) {
  final patterns = <({TemporalRelation relation, RegExp expression})>[
    (
      relation: TemporalRelation.before,
      expression: RegExp(r'\b(?:before|antes d(?:a|e|o))\s+(.+)$'),
    ),
    (
      relation: TemporalRelation.during,
      expression: RegExp(r'\b(?:during|durante)\s+(?:a\s+|o\s+|the\s+)?(.+)$'),
    ),
    (
      relation: TemporalRelation.lastOccurrence,
      expression: RegExp(
        r'\b(?:last time(?: that)?|ultima vez(?: que)?)\s+(.+)$',
      ),
    ),
  ];
  for (final pattern in patterns) {
    final match = pattern.expression.firstMatch(query);
    final anchor = match?.group(1)?.trim();
    if (anchor != null && anchor.isNotEmpty) {
      return (relation: pattern.relation, anchor: anchor);
    }
  }
  return null;
}

bool _isWeekPhrase(String query) =>
    _containsAny(query, const ['week', 'semana']);

({DateTime start, DateTime end, bool fuzzy, double confidence}) _narrowWeek(
  String query,
  DateTime start,
  DateTime end,
) {
  if (_containsAny(query, const ['beginning', 'start', 'inicio', 'comeco'])) {
    return (
      start: start,
      end: start.add(const Duration(days: 2)),
      fuzzy: true,
      confidence: 0.8,
    );
  }
  if (_containsAny(query, const ['middle', 'midweek', 'meio', 'meados'])) {
    return (
      start: start.add(const Duration(days: 2)),
      end: start.add(const Duration(days: 4)),
      fuzzy: true,
      confidence: 0.75,
    );
  }
  if (_containsAny(query, const ['end', 'fim', 'final'])) {
    return (
      start: end.subtract(const Duration(days: 3)),
      end: end,
      fuzzy: true,
      confidence: 0.8,
    );
  }
  return (start: start, end: end, fuzzy: false, confidence: 1);
}

int? _relativeDayCount(String query) {
  final match = RegExp(
    r'\b(?:ha\s+(\d+)\s+dias?|(\d+)\s+(?:days?\s+ago|dias?\s+atras))\b',
  ).firstMatch(query);
  if (match == null) return null;
  return _boundedDayCount(match.group(1) ?? match.group(2));
}

int? _recentDayCount(String query) {
  final match = RegExp(
    r'\b(?:last|past|ultimos?)\s+(\d+)\s+(?:days?|dias?)\b',
  ).firstMatch(query);
  if (match == null) return null;
  return _boundedDayCount(match.group(1));
}

int? _boundedDayCount(String? value) {
  final count = int.tryParse(value ?? '');
  return count != null && count > 0 && count <= maxTemporalLookbackDays
      ? count
      : null;
}

({int year, int month})? _month(String query, DateTime reference) {
  const names = {
    'january': 1,
    'janeiro': 1,
    'february': 2,
    'fevereiro': 2,
    'march': 3,
    'marco': 3,
    'april': 4,
    'abril': 4,
    'may': 5,
    'maio': 5,
    'june': 6,
    'junho': 6,
    'july': 7,
    'julho': 7,
    'august': 8,
    'agosto': 8,
    'september': 9,
    'setembro': 9,
    'october': 10,
    'outubro': 10,
    'november': 11,
    'novembro': 11,
    'december': 12,
    'dezembro': 12,
  };
  for (final entry in names.entries) {
    if (!query.contains(entry.key)) continue;
    final yearMatch = RegExp(r'\b(20\d{2})\b').firstMatch(query);
    var year =
        yearMatch == null ? reference.year : int.parse(yearMatch.group(1)!);
    if (yearMatch == null && entry.value > reference.month) year--;
    return (year: year, month: entry.value);
  }
  return null;
}

Duration? _timezoneOffset(String query) {
  if (_containsAny(query, const [
    'brt',
    'brasilia time',
    'horario de brasilia',
  ])) {
    return const Duration(hours: -3);
  }
  final match = RegExp(
    r'\b(?:utc|gmt)\s*([+-])(\d{1,2})(?::?(\d{2}))?\b',
  ).firstMatch(query);
  if (match != null) {
    final sign = match.group(1) == '-' ? -1 : 1;
    final hours = int.parse(match.group(2)!);
    final minutes = int.tryParse(match.group(3) ?? '') ?? 0;
    if (hours <= 14 && minutes <= 59) {
      return Duration(minutes: sign * (hours * 60 + minutes));
    }
    return null;
  }
  return RegExp(r'\b(?:utc|gmt)\b(?!\s*[+-])').hasMatch(query)
      ? Duration.zero
      : null;
}

DateTime? _toInstant(DateTime? wall, Duration? offset, bool referenceIsUtc) {
  if (wall == null) return null;
  if (offset != null) {
    return DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
      wall.second,
    ).subtract(offset);
  }
  return referenceIsUtc
      ? DateTime.utc(
        wall.year,
        wall.month,
        wall.day,
        wall.hour,
        wall.minute,
        wall.second,
      )
      : wall;
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áàâãä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòôõö]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll('ç', 'c');
