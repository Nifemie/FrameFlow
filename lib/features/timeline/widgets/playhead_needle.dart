import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PlayheadNeedle extends StatelessWidget {
  final double positionX;
  final double height;
  final Color color;
  final GestureDragStartCallback? onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final VoidCallback? onDragEnd;

  const PlayheadNeedle({
    super.key,
    required this.positionX,
    required this.height,
    this.color = AppColors.playheadNeedle,
    this.onDragStart,
    required this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: positionX - 12,
      top: 0,
      bottom: 0,
      width: 24,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Visual needle line down all tracks (non-blocking for underlying clips)
          Positioned(
            top: 10,
            bottom: 0,
            width: 2,
            child: IgnorePointer(
              child: Container(
                width: 2,
                height: height,
                color: color,
              ),
            ),
          ),
          // Top grabbable ruler marker
          Positioned(
            top: 0,
            width: 24,
            height: 20,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: onDragStart,
                onHorizontalDragUpdate: onDragUpdate,
                onHorizontalDragEnd: (_) => onDragEnd?.call(),
                child: CustomPaint(
                  size: const Size(16, 12),
                  painter: _PlayheadMarkerPainter(color),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayheadMarkerPainter extends CustomPainter {
  final Color color;
  const _PlayheadMarkerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.6)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height * 0.6)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PlayheadMarkerPainter oldDelegate) => oldDelegate.color != color;
}
