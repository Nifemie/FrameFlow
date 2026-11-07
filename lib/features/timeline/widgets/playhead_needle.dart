import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PlayheadNeedle extends StatelessWidget {
  final double positionX;
  final double height;
  final ValueChanged<double> onDragUpdate;

  const PlayheadNeedle({
    super.key,
    required this.positionX,
    required this.height,
    required this.onDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: positionX - 6,
      top: 0,
      bottom: 0,
      width: 12,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) {
          onDragUpdate(details.delta.dx);
        },
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Vertical orange line
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 2,
              height: height,
              color: AppColors.playheadNeedle,
            ),

            // Top orange marker handle
            CustomPaint(
              size: const Size(12, 10),
              painter: _PlayheadMarkerPainter(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayheadMarkerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.playheadNeedle
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
