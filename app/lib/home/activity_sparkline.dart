import 'package:flutter/material.dart';
import 'package:kangoos_core/kangoos_core.dart';

/// Buckets today's activity into 24 hourly counts (index 0 = midnight).
List<int> bucketActivityByHour(List<Activity> activities, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final buckets = List<int>.filled(24, 0);
  for (final activity in activities) {
    final local = activity.capturedAt.toLocal();
    if (local.year == today.year &&
        local.month == today.month &&
        local.day == today.day) {
      buckets[local.hour]++;
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
    required this.hourlyCounts,
    this.isCapturing = true,
    this.now,
  });

  final List<int> hourlyCounts;
  final bool isCapturing;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasData = hourlyCounts.any((count) => count > 0);
    final resolvedNow = now ?? DateTime.now();
    final nowFraction =
        (resolvedNow.hour * 60 + resolvedNow.minute) / (24 * 60);
    final liveColor = isCapturing ? colors.primary : colors.onSurfaceVariant;

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
                            counts: hourlyCounts,
                            lineColor: colors.primary,
                            fillColor: colors.primary.withValues(alpha: 0.14),
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
                              border:
                                  Border.all(color: colors.surface, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                )
              : Center(
                  child: Text(
                    'Activity will show up here as you work.',
                    style: textTheme.bodySmall,
                  ),
                ),
        ),
        if (hasData) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('12am', style: textTheme.bodySmall),
              Text('6am', style: textTheme.bodySmall),
              Text('12pm', style: textTheme.bodySmall),
              Text('6pm', style: textTheme.bodySmall),
              Text('12am', style: textTheme.bodySmall),
            ],
          ),
        ],
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(
      {required this.counts, required this.lineColor, required this.fillColor});

  final List<int> counts;
  final Color lineColor;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final maxCount = counts.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    final stepX = size.width / (counts.length - 1);

    Offset pointAt(int index) {
      final normalized = counts[index] / maxCount;
      final y = size.height - (normalized * size.height * 0.85) - 4;
      return Offset(stepX * index, y);
    }

    final line = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < counts.length; i++) {
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
      oldDelegate.counts != counts || oldDelegate.lineColor != lineColor;
}
