import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';

class TimelineRuler extends StatelessWidget {
  final int totalDurationMs;
  final double pixelsPerSecond;
  final ValueChanged<int> onSeek;
  final ValueChanged<int>? onScrub;
  final VoidCallback? onScrubEnd;
  final void Function(TapUpDetails details, int clickMs)? onSecondaryTapUp;

  const TimelineRuler({
    super.key,
    required this.totalDurationMs,
    required this.pixelsPerSecond,
    required this.onSeek,
    this.onScrub,
    this.onScrubEnd,
    this.onSecondaryTapUp,
  });

  int _msAt(double localDx) {
    final maxSec = totalDurationMs > 0 ? (totalDurationMs / 1000.0) : 3600.0;
    final sec = (localDx / pixelsPerSecond).clamp(0.0, maxSec);
    return (sec * 1000).round();
  }

  void _seekToPosition(double localDx, {bool isScrub = false}) {
    final ms = _msAt(localDx);
    if (isScrub && onScrub != null) {
      onScrub!(ms);
    } else {
      onSeek(ms);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = (totalDurationMs / 1000).ceil().clamp(10, 3600);
    final totalWidth = totalSeconds * pixelsPerSecond;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) => _seekToPosition(details.localPosition.dx),
        onSecondaryTapUp: onSecondaryTapUp != null
            ? (details) => onSecondaryTapUp!(details, _msAt(details.localPosition.dx))
            : null,
        onHorizontalDragStart: (details) => _seekToPosition(details.localPosition.dx, isScrub: true),
        onHorizontalDragUpdate: (details) => _seekToPosition(details.localPosition.dx, isScrub: true),
        onHorizontalDragEnd: (_) => onScrubEnd?.call(),
        child: CustomPaint(
          size: Size(totalWidth, 24),
          painter: _RulerPainter(
            totalSeconds: totalSeconds,
            pixelsPerSecond: pixelsPerSecond,
          ),
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

    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), linePaint);

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
        canvas.drawLine(Offset(x, size.height - 10), Offset(x, size.height), majorLinePaint);
        final textSpan = TextSpan(text: TimeParser.formatStandard(sec * 1000), style: textStyle);
        final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(x + 2, 2));
      } else if (pixelsPerSecond > 20) {
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
