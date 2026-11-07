import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ExportProgressCard extends StatelessWidget {
  final double progress;
  final String statusText;
  final bool isCompleted;
  final String? outputPath;
  final VoidCallback onCancel;
  final VoidCallback onClose;

  const ExportProgressCard({
    super.key,
    required this.progress,
    required this.statusText,
    required this.isCompleted,
    this.outputPath,
    required this.onCancel,
    required this.onClose,
  });

  void _openVideo() {
    if (outputPath != null && File(outputPath!).existsSync()) {
      Process.run('explorer.exe', [outputPath!]);
    }
  }

  void _openFolder() {
    if (outputPath != null && File(outputPath!).existsSync()) {
      Process.run('explorer.exe', ['/select,', outputPath!]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).toStringAsFixed(1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isCompleted ? Icons.check_circle : Icons.hourglass_top_rounded,
              color: isCompleted ? AppColors.exportGreen : AppColors.clipBlue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              isCompleted ? 'Video Export Complete!' : 'Exporting Video ($pct%)',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Progress indicator
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.background,
            valueColor: AlwaysStoppedAnimation(
              isCompleted ? AppColors.exportGreen : AppColors.clipBlue,
            ),
          ),
        ),
        const SizedBox(height: 10),

        Text(
          statusText,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),

        // Action Buttons
        if (isCompleted)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.surfaceBorder),
                ),
                onPressed: _openFolder,
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('Show in Folder'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.exportGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: _openVideo,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: const Text('Play Video'),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: onClose, child: const Text('Close')),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onCancel,
                child: const Text('Cancel Export', style: TextStyle(color: AppColors.errorRed)),
              ),
            ],
          ),
      ],
    );
  }
}
