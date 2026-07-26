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
}
