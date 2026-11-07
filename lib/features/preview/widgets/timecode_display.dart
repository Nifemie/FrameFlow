import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';

class TimecodeDisplay extends StatelessWidget {
  final int currentMs;
  final int totalMs;

  const TimecodeDisplay({
    super.key,
    required this.currentMs,
    required this.totalMs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            TimeParser.formatDetailed(currentMs),
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.accentOrange,
              letterSpacing: 0.5,
            ),
          ),
          const Text(
            ' / ',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          Text(
            TimeParser.formatDetailed(totalMs),
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: 12,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
