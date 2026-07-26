import '../database/database.dart';

const defaultActivityGapCap = Duration(minutes: 10);

class ActivitySpan {
  const ActivitySpan({required this.activity, required this.duration});

  final Activity activity;
  final Duration duration;
}

List<ActivitySpan> activitySpans(
  List<Activity> ascendingByCapturedAt, {
  required DateTime until,
  Duration gapCap = defaultActivityGapCap,
}) {
  final spans = <ActivitySpan>[];
  for (var i = 0; i < ascendingByCapturedAt.length; i++) {
    final activity = ascendingByCapturedAt[i];
    final next = i + 1 < ascendingByCapturedAt.length
        ? ascendingByCapturedAt[i + 1].capturedAt
        : until;
    final gap = next.difference(activity.capturedAt);
    final duration = gap.isNegative
        ? Duration.zero
        : (gap > gapCap ? gapCap : gap);
    spans.add(ActivitySpan(activity: activity, duration: duration));
  }
  return spans;
}

String formatActivityDuration(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 1) return '${duration.inSeconds}s';
  if (minutes < 60) return '${minutes}m';
  final hours = duration.inHours;
  final remainder = minutes - hours * 60;
  return remainder == 0 ? '${hours}h' : '${hours}h${remainder}m';
}
