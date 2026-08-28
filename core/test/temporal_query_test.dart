import 'package:kangoos_core/kangoos_core.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime(2026, 7, 22, 14, 30);

  test('defaults to today when no temporal keyword is present', () {
    final range = parseTemporalRange('what did I work on?', now: now);
    expect(range.start, DateTime(2026, 7, 22));
    expect(range.end, now);
  });

  test('"yesterday" resolves to the full previous day', () {
    final range = parseTemporalRange('what did I do yesterday?', now: now);
    expect(range.start, DateTime(2026, 7, 21));
    expect(range.end, DateTime(2026, 7, 22));
  });

  test('"last week" resolves to the calendar week before this one', () {
    final range = parseTemporalRange('summarize last week', now: now);
    expect(range.start, DateTime(2026, 7, 13));
    expect(range.end, DateTime(2026, 7, 20));
  });

  test('"this week" resolves from Monday through now', () {
    final range = parseTemporalRange('what have I done this week?', now: now);
    expect(range.start, DateTime(2026, 7, 20));
    expect(range.end, now);
  });

  test('understands strict past weekdays and approximate periods in PT-BR', () {
    const parser = RuleBasedTemporalParser();
    final tuesday = DateTime(2026, 7, 21, 14, 30);

    final pastTuesday = parser.parseSync('terça passada', tuesday);
    final recent = parser.parseSync('recentemente', tuesday);
    final midweek = parser.parseSync('meados da semana passada', tuesday);

    expect(pastTuesday.start, DateTime(2026, 7, 14));
    expect(pastTuesday.end, DateTime(2026, 7, 15));
    expect(recent.start, tuesday.subtract(const Duration(days: 7)));
    expect(recent.end, tuesday);
    expect(recent.fuzzy, isTrue);
    expect(recent.confidence, 0.65);
    expect(midweek.start, DateTime(2026, 7, 15));
    expect(midweek.end, DateTime(2026, 7, 17));
    expect(midweek.fuzzy, isTrue);
  });

  test('extracts event anchors in Portuguese and English', () {
    const parser = RuleBasedTemporalParser();

    final before = parser.parseSync('antes da entrevista', now);
    final during = parser.parseSync('during the meeting', now);
    final last = parser.parseSync('última vez que usei Docker', now);

    expect(before.relation, TemporalRelation.before);
    expect(before.anchor, 'entrevista');
    expect(during.relation, TemporalRelation.during);
    expect(during.anchor, 'meeting');
    expect(last.relation, TemporalRelation.lastOccurrence);
    expect(last.anchor, 'usei docker');
    expect(last.fuzzy, isTrue);
    expect(last.confidence, 0.65);
  });
}
