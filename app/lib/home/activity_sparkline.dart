import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:kangoos_core/kangoos_core.dart';

/// Buckets today's activity into 24 hourly totals of focused minutes
/// (index 0 = midnight), splitting a span that crosses an hour boundary.
List<double> bucketActivityMinutesByHour(List<Activity> activities,
    {DateTime? now}) {
  final current = now ?? DateTime.now();
  final buckets = List<double>.filled(24, 0);
  final spans = activitySpans(activities, until: current);

  for (final span in spans) {
    var cursor = span.activity.capturedAt.toLocal();
    var remaining = span.duration;
    while (remaining > Duration.zero && cursor.day == current.day) {
      final nextHour = DateTime(cursor.year, cursor.month, cursor.day)
          .add(Duration(hours: cursor.hour + 1));
      final untilNextHour = nextHour.difference(cursor);
      final slice = remaining < untilNextHour ? remaining : untilNextHour;
      buckets[cursor.hour] += slice.inSeconds / Duration.secondsPerMinute;
      remaining -= slice;
      cursor = cursor.add(slice);
      if (cursor.hour == 0 && slice == untilNextHour) break;
    }
  }
  return buckets;
}

/// Today's activity as an area chart, with a time-of-day axis and a live
/// indicator dot at the current time — green while capture is running,
/// gray while paused.
class ActivitySparkline extends StatelessWidget {
  const ActivitySparkline({
    super.key,
    required this.hourlyMinutes,
    this.isCapturing = true,
    this.now,
    this.foregroundColor,
    this.backgroundColor,
  });

  final List<double> hourlyMinutes;
  final bool isCapturing;
  final DateTime? now;
  final Color? foregroundColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final hasData = hourlyMinutes.any((minutes) => minutes > 0);
    final resolvedNow = now ?? DateTime.now();
    final graphColor = foregroundColor ?? colors.primary;
    final labelStyle = textTheme.bodySmall?.copyWith(color: foregroundColor);
    final nowFraction =
        (resolvedNow.hour * 60 + resolvedNow.minute) / (24 * 60);
    final liveColor = isCapturing ? graphColor : colors.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 72,
          child: hasData
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CustomPaint(
                          size: Size.infinite,
                          painter: _SparklinePainter(
                            minutes: hourlyMinutes,
                            lineColor: graphColor,
                            fillColor: graphColor.withValues(alpha: 0.18),
                          ),
                        ),
                        Positioned(
                          left: nowFraction * constraints.maxWidth - 4,
                          top: 12,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: liveColor,
                              border: Border.all(
                                  color: backgroundColor ?? colors.surface,
                                  width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                )
              : Center(
                  child: Text(
                    l10n.activityEmptyHint,
                    style: labelStyle,
                  ),
                ),
        ),
        if (hasData) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('00h', style: labelStyle),
              Text('06h', style: labelStyle),
              Text('12h', style: labelStyle),
              Text('18h', style: labelStyle),
              Text('24h', style: labelStyle),
            ],
          ),
        ],
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(
      {required this.minutes,
      required this.lineColor,
      required this.fillColor});

  final List<double> minutes;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final busiestHour =
        minutes.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);
    final stepX = size.width / (minutes.length - 1);

    Offset pointAt(int index) {
      final normalized = minutes[index] / busiestHour;
      final y = size.height - (normalized * size.height * 0.85) - 4;
      return Offset(stepX * index, y);
    }

    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < minutes.length; i++) {
      final previous = pointAt(i - 1);
      final current = pointAt(i);
      final midX = (previous.dx + current.dx) / 2;
      line.cubicTo(midX, previous.dy, midX, current.dy, current.dx, current.dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fill, Paint()..color = fillColor);
    canvas.drawPath(
      line,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.minutes != minutes || oldDelegate.lineColor != lineColor;
}
