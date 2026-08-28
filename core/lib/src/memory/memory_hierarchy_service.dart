import '../database/database.dart';
import '../database/tables/activity_summaries_table.dart';
import 'episode_repository.dart';
import 'summary_repository.dart';

const defaultSessionGap = Duration(hours: 2);
const durableRecurrenceMinimumEpisodes = 3;
const durableRecurrenceMinimumDays = 2;

class HierarchyCompactionReport {
  const HierarchyCompactionReport({
    required this.sessions,
    required this.daily,
    required this.weekly,
    this.durable = 0,
  });

  final int sessions;
  final int daily;
  final int weekly;
  final int durable;

  int get created => sessions + daily + weekly + durable;
}

class MemoryHierarchyService {
  const MemoryHierarchyService({
    required this.episodes,
    required this.summaries,
    this.sessionGap = defaultSessionGap,
  });

  final EpisodeRepository episodes;
  final SummaryRepository summaries;
  final Duration sessionGap;

  Future<HierarchyCompactionReport> compact(
    DateTime start,
    DateTime end,
  ) async {
    if (!start.isBefore(end)) {
      return const HierarchyCompactionReport(
        sessions: 0,
        daily: 0,
        weekly: 0,
      );
    }
    final captured = await episodes.between(start, end);
    captured.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    if (captured.isEmpty) {
      return const HierarchyCompactionReport(
        sessions: 0,
        daily: 0,
        weekly: 0,
      );
    }

    final existing = await summaries.between(start, end);
    var sessionCount = 0;
    for (final group in _sessions(captured)) {
      if (await _createIfMissing(
        existing,
        SummaryKind.session,
        group.first.startedAt,
        group.last.endedAt,
        _sessionContent(group),
      )) {
        sessionCount++;
      }
    }

    var dailyCount = 0;
    for (final entry in _byDay(captured, start.isUtc).entries) {
      final dayStart = entry.key;
      final dayEnd = dayStart.add(const Duration(days: 1));
      if (dayEnd.isAfter(end)) continue;
      if (await _createIfMissing(
        existing,
        SummaryKind.daily,
        dayStart,
        dayEnd,
        _dailyContent(dayStart, entry.value),
      )) {
        dailyCount++;
      }
    }

    var weeklyCount = 0;
    for (final entry in _byWeek(captured, start.isUtc).entries) {
      final weekStart = entry.key;
      final weekEnd = weekStart.add(const Duration(days: 7));
      if (weekStart.isBefore(_day(start)) || weekEnd.isAfter(end)) continue;
      if (await _createIfMissing(
        existing,
        SummaryKind.weekly,
        weekStart,
        weekEnd,
        _weeklyContent(weekStart, entry.value),
      )) {
        weeklyCount++;
      }
    }

    final durableCount = await _promoteDurable(captured, existing);

    return HierarchyCompactionReport(
      sessions: sessionCount,
      daily: dailyCount,
      weekly: weeklyCount,
      durable: durableCount,
    );
  }

  Future<int> _promoteDurable(
    List<MemoryEpisode> episodes,
    List<ActivitySummary> existing,
  ) async {
    final durableMemories = (await summaries.all())
        .where((summary) => summary.kind == SummaryKind.durable)
        .toList();
    final evidence = <String, List<MemoryEpisode>>{};
    final labels = <String, String>{};
    for (final episode in episodes) {
      final candidates = <String, String>{
        for (final technology in episode.technologies)
          'technology:${_normalize(technology)}': technology,
        for (final entity in episode.entities)
          if (entity.startsWith('project:') || entity.startsWith('person:'))
            '${entity.substring(0, entity.indexOf(':'))}:'
                '${_normalize(entity.substring(entity.indexOf(':') + 1))}':
              entity.substring(entity.indexOf(':') + 1),
        for (final decision in episode.decisions)
          'decision:${_normalize(decision)}': decision,
      };
      for (final entry in candidates.entries) {
        labels.putIfAbsent(entry.key, () => entry.value.trim());
        evidence.putIfAbsent(entry.key, () => []).add(episode);
      }
    }

    var created = 0;
    final keys = evidence.keys.toList()..sort();
    for (final key in keys) {
      final matches = evidence[key]!;
      final days = matches.map((episode) => _day(episode.startedAt)).toSet();
      if (matches.length < durableRecurrenceMinimumEpisodes ||
          days.length < durableRecurrenceMinimumDays) {
        continue;
      }
      final marker = '$automaticDurableMemoryPrefix$key]';
      if (durableMemories
          .any((summary) => summary.content.startsWith(marker))) {
        continue;
      }
      final content = [
        marker,
        'Memória recorrente: ${labels[key]}',
        'Evidências:',
        for (final episode in matches)
          '- episódio #${episode.id} · ${episode.startedAt.toIso8601String()} · '
              '${episode.title}',
      ].join('\n');
      final id = await summaries.create(NewActivitySummary(
        kind: SummaryKind.durable,
        periodStart: matches.first.startedAt,
        periodEnd: matches.last.endedAt,
        content: content,
      ));
      final stored = await summaries.getById(id);
      if (stored == null) {
        throw StateError('Created durable memory #$id could not be loaded.');
      }
      existing.add(stored);
      durableMemories.add(stored);
      created++;
    }
    return created;
  }

  Future<bool> _createIfMissing(
    List<ActivitySummary> existing,
    SummaryKind kind,
    DateTime start,
    DateTime end,
    String content,
  ) async {
    if (existing.any((summary) =>
        summary.kind == kind &&
        summary.periodStart.isAtSameMomentAs(start) &&
        summary.periodEnd.isAtSameMomentAs(end))) {
      return false;
    }
    final id = await summaries.create(NewActivitySummary(
      kind: kind,
      periodStart: start,
      periodEnd: end,
      content: content,
    ));
    final created = await summaries.getById(id);
    if (created == null) {
      throw StateError('Created hierarchical memory #$id could not be loaded.');
    }
    existing.add(created);
    return true;
  }

  List<List<MemoryEpisode>> _sessions(List<MemoryEpisode> episodes) {
    final groups = <List<MemoryEpisode>>[];
    for (final episode in episodes) {
      if (groups.isEmpty ||
          episode.startedAt.difference(groups.last.last.endedAt) > sessionGap) {
        groups.add([episode]);
      } else {
        groups.last.add(episode);
      }
    }
    return groups;
  }

  Map<DateTime, List<MemoryEpisode>> _byDay(
    List<MemoryEpisode> episodes,
    bool useUtc,
  ) {
    final groups = <DateTime, List<MemoryEpisode>>{};
    for (final episode in episodes) {
      groups
          .putIfAbsent(_day(episode.startedAt, useUtc), () => [])
          .add(episode);
    }
    return groups;
  }

  Map<DateTime, List<MemoryEpisode>> _byWeek(
    List<MemoryEpisode> episodes,
    bool useUtc,
  ) {
    final groups = <DateTime, List<MemoryEpisode>>{};
    for (final episode in episodes) {
      final day = _day(episode.startedAt, useUtc);
      final week = day.subtract(Duration(days: day.weekday - DateTime.monday));
      groups.putIfAbsent(week, () => []).add(episode);
    }
    return groups;
  }

  String _sessionContent(List<MemoryEpisode> episodes) => [
        'Session ${_date(episodes.first.startedAt)} '
            '${_time(episodes.first.startedAt)}–${_time(episodes.last.endedAt)}',
        for (final episode in episodes)
          '- ${episode.title}: ${episode.summary}',
      ].join('\n');

  String _dailyContent(DateTime day, List<MemoryEpisode> episodes) => [
        'Daily memory ${_date(day)}',
        for (final episode in episodes)
          '- ${_time(episode.startedAt)} ${episode.title}: ${episode.summary}',
      ].join('\n');

  String _weeklyContent(DateTime week, List<MemoryEpisode> episodes) {
    final byDay = _byDay(episodes, week.isUtc);
    return [
      'Weekly memory ${_date(week)}–${_date(week.add(const Duration(days: 6)))}',
      for (final entry in byDay.entries) ...[
        '${_date(entry.key)}:',
        for (final episode in entry.value) '- ${episode.title}',
      ],
    ].join('\n');
  }
}

String _normalize(String value) =>
    value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

DateTime _day(DateTime value, [bool? useUtc]) {
  final utc = useUtc ?? value.isUtc;
  final normalized = utc ? value.toUtc() : value.toLocal();
  return utc
      ? DateTime.utc(normalized.year, normalized.month, normalized.day)
      : DateTime(normalized.year, normalized.month, normalized.day);
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
