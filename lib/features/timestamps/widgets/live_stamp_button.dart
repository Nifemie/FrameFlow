import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';

class LiveStampButton extends ConsumerWidget {
  const LiveStampButton({super.key});

  void stampCut(BuildContext context, WidgetRef ref) {
    final playheadMs = ref.read(playheadPositionProvider);
    final fileName = ref.read(projectProvider.notifier).stampCurrentCutPoint(playheadMs);

    if (fileName != null) {
      final timeFormatted = TimeParser.formatDetailed(playheadMs);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1500),
          backgroundColor: AppColors.surfaceLight,
          content: Text(
            '✂️ Cut "$fileName" stamped at $timeFormatted',
            style: const TextStyle(fontSize: 12, color: AppColors.accentOrange, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accentOrange.withValues(alpha: 0.15),
        foregroundColor: AppColors.accentOrange,
        side: const BorderSide(color: AppColors.accentOrange, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onPressed: () => stampCut(context, ref),
      icon: const Icon(Icons.bookmark_add, size: 14),
      label: const Text(
        'Stamp Cut (M)',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
