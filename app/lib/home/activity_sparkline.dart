import 'package:flutter/material.dart';
import 'package:kangoos_core/kangoos_core.dart';

/// Buckets today's activity into 24 hourly counts (index 0 = midnight).
List<int> bucketActivityByHour(List<Activity> activities, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final buckets = List<int>.filled(24, 0);
  for (final activity in activities) {
    final local = activity.capturedAt.toLocal();
    if (local.year == today.year && local.month == today.month && local.day == today.day) {
      buckets[local.hour]++;
    }
  }
  return buckets;
}

class ActivitySparkline extends StatelessWidget {
  const ActivitySparkline({super.key, required this.hourlyCounts});

  final List<int> hourlyCounts;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasData = hourlyCounts.any((count) => count > 0);
    return SizedBox(
      height: 72,
      child: hasData
          ? CustomPaint(
              size: Size.infinite,
              painter: _SparklinePainter(
                counts: hourlyCounts,
                lineColor: colors.primary,
                fillColor: colors.primary.withValues(alpha: 0.14),
              ),
            )
          : Center(
              child: Text(
                'Activity will show up here as you work.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.counts, required this.lineColor, required this.fillColor});

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

    final endPoint = pointAt(counts.length - 1);
    canvas.drawCircle(endPoint, 3.5, Paint()..color = lineColor);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.counts != counts || oldDelegate.lineColor != lineColor;
}
