import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/image_item.dart';
import '../../../providers/project_provider.dart';

class TimelineGapItem extends ConsumerWidget {
  final int startMs;
  final int endMs;
  final double pxPerSec;
  final String trackId;
  final VoidCallback? onTap;

  const TimelineGapItem({
    super.key,
    required this.startMs,
    required this.endMs,
    required this.pxPerSec,
    required this.trackId,
    this.onTap,
  });

  Future<void> _pickImageToFill(WidgetRef ref) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: AppConstants.supportedImageExtensions);
    if (res != null && res.paths.isNotEmpty && res.paths.first != null) {
      ref.read(projectProvider.notifier).fillBlankGap(startMs: startMs, endMs: endMs, trackId: trackId, isColorBg: false, imagePath: res.paths.first!);
    }
  }

  void _fillColorMatte(WidgetRef ref) {
    ref.read(projectProvider.notifier).fillBlankGap(startMs: startMs, endMs: endMs, trackId: trackId, isColorBg: true, color: const Color(0xFF1E293B));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final left = (startMs / 1000) * pxPerSec;
    final width = ((endMs - startMs) / 1000) * pxPerSec;
    final durationSec = ((endMs - startMs) / 1000).toStringAsFixed(1);

    return Positioned(
      left: left, top: 2, bottom: 2, width: width,
      child: DragTarget<ImageItem>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) {
          ref.read(projectProvider.notifier).moveImageClipStart(details.data.id, startMs);
        },
        builder: (context, candidateData, _) {
          final isTargeted = candidateData.isNotEmpty;
          return PopupMenuButton<String>(
            tooltip: 'Fill Blank Gap (${durationSec}s)',
            padding: EdgeInsets.zero,
            color: AppColors.surface,
            onSelected: (val) {
              if (val == 'image') _pickImageToFill(ref);
              if (val == 'color') _fillColorMatte(ref);
              if (val == 'seek') onTap?.call();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'seek', child: Row(children: [const Icon(Icons.play_arrow, size: 14, color: Colors.white70), const SizedBox(width: 8), Text('Seek to $durationSec s', style: const TextStyle(fontSize: 11, color: Colors.white))])),
              PopupMenuItem(value: 'color', child: Row(children: [const Icon(Icons.palette_outlined, size: 14, color: Colors.purpleAccent), const SizedBox(width: 8), Text('Fill Gap with Color Matte ($durationSec s)', style: const TextStyle(fontSize: 11, color: Colors.white))])),
              PopupMenuItem(value: 'image', child: Row(children: [const Icon(Icons.add_photo_alternate, size: 14, color: AppColors.clipBlue), const SizedBox(width: 8), Text('Fill Gap with Image ($durationSec s)', style: const TextStyle(fontSize: 11, color: Colors.white))])),
            ],
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: isTargeted ? AppColors.clipBlue.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isTargeted ? AppColors.clipBlue : Colors.white24, width: isTargeted ? 1.5 : 1.0),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_outlined, size: 12, color: Colors.white54),
                    if (width > 50) ...[
                      const SizedBox(width: 4),
                      Text('Blank ($durationSec s)', style: const TextStyle(fontSize: 8.5, color: Colors.white70, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
