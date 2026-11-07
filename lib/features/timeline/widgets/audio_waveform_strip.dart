import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/voice_over.dart';

class AudioWaveformStrip extends StatelessWidget {
  final VoiceOver voiceOver;
  final double width;

  const AudioWaveformStrip({
    super.key,
    required this.voiceOver,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width.clamp(150.0, 50000.0);

    return Container(
      width: effectiveWidth,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.waveform.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Waveform bars
          CustomPaint(
            size: Size(effectiveWidth, 36),
            painter: _WaveformPainter(fileName: voiceOver.fileName),
          ),

          // Label
          Positioned(
            left: 8,
            top: 4,
            child: Row(
              children: [
                const Icon(Icons.audiotrack, size: 12, color: AppColors.waveform),
                const SizedBox(width: 4),
                Text(
                  voiceOver.fileName,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final String fileName;

  _WaveformPainter({required this.fileName});

  @override
  void paint(Canvas canvas, Size size) {
    final barPaint = Paint()
      ..color = AppColors.waveform.withValues(alpha: 0.75)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    const barSpacing = 4.0;
    final barCount = (size.width / barSpacing).floor();

    // Deterministic pseudo-random peaks derived from filename
    final seed = fileName.hashCode;
    final random = Random(seed);

    for (int i = 0; i < barCount; i++) {
      final x = i * barSpacing + 2.0;
      // Generate varying amplitude peaks
      final amplitude = (random.nextDouble() * 0.7 + 0.3) * (size.height / 2 - 4);
      canvas.drawLine(
        Offset(x, centerY - amplitude),
        Offset(x, centerY + amplitude),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.fileName != fileName;
  }
}
