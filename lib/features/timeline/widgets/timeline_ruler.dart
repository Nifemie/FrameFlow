import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';

class TimelineRuler extends StatelessWidget {
  final int totalDurationMs;
  final double pixelsPerSecond;
  final ValueChanged<int> onSeek;

  const TimelineRuler({
    super.key,
    required this.totalDurationMs,
    required this.pixelsPerSecond,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final totalSeconds = (totalDurationMs / 1000).ceil().clamp(10, 3600);
    final totalWidth = totalSeconds * pixelsPerSecond;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        final sec = details.localPosition.dx / pixelsPerSecond;
        onSeek((sec * 1000).round());
      },
      child: CustomPaint(
        size: Size(totalWidth, 24),
        painter: _RulerPainter(
          totalSeconds: totalSeconds,
          pixelsPerSecond: pixelsPerSecond,
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final int totalSeconds;
  final double pixelsPerSecond;

  _RulerPainter({
    required this.totalSeconds,
    required this.pixelsPerSecond,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.surfaceBorder
      ..strokeWidth = 1.0;

    final majorLinePaint = Paint()
      ..color = AppColors.textSecondary
      ..strokeWidth = 1.0;

    // Bottom baseline
    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      linePaint,
    );

    // Determine interval for text labels based on zoom
    final stepSeconds = (pixelsPerSecond > 60)
        ? 1
        : (pixelsPerSecond > 30)
            ? 5
            : 10;

    final textStyle = const TextStyle(
      color: AppColors.textMuted,
      fontSize: 9,
      fontFamily: 'Consolas',
    );

    for (int sec = 0; sec <= totalSeconds; sec++) {
      final x = sec * pixelsPerSecond;
      final isMajor = (sec % stepSeconds == 0);

      if (isMajor) {
        // Major tick
        canvas.drawLine(Offset(x, size.height - 10), Offset(x, size.height), majorLinePaint);

        // Time label
        final textSpan = TextSpan(text: TimeParser.formatStandard(sec * 1000), style: textStyle);
        final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(x + 2, 2));
      } else if (pixelsPerSecond > 20) {
        // Minor tick
        canvas.drawLine(Offset(x, size.height - 4), Offset(x, size.height), linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) {
    return oldDelegate.totalSeconds != totalSeconds ||
        oldDelegate.pixelsPerSecond != pixelsPerSecond;
  }
}
