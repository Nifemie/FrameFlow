import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/image_item.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../services/timeline_arrangement_service.dart';

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
          final box = context.findRenderObject() as RenderBox?;
          int dropMs = startMs;
          if (box != null && box.hasSize) {
            // details.offset is top-left of the 75px feedback card; use center X for accurate cursor position
            final centerGlobal = Offset(details.offset.dx + 37.5, details.offset.dy);
            final local = box.globalToLocal(centerGlobal);
            final offsetMs = ((local.dx.clamp(0.0, box.size.width) / pxPerSec) * 1000).round();
            dropMs = (startMs + offsetMs).clamp(startMs, endMs - 200);
          }
          final snapOn = ref.read(snappingEnabledProvider);
          final project = ref.read(projectProvider);
          final targets = <int>[
            startMs,
            endMs,
            ref.read(playheadPositionProvider),
            ...project.markers.map((m) => m.timestampMs),
          ];
          final (snappedMs, _) = TimelineArrangementService.snapToTargets(
            targetMs: dropMs,
            targets: targets,
            pxPerSec: pxPerSec,
            enabled: snapOn,
          );
          final targetStart = snappedMs.clamp(startMs, endMs - 200);
          ref.read(projectProvider.notifier).fillBlankGap(
            startMs: targetStart,
            endMs: endMs,
            trackId: trackId,
            isColorBg: false,
            existingClipId: details.data.id,
          );
        },
        builder: (context, candidateData, _) {
          final isTargeted = candidateData.isNotEmpty;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            onSecondaryTapUp: (details) async {
              final val = await showMenu<String>(
                context: context,
                color: AppColors.surface,
                position: RelativeRect.fromLTRB(details.globalPosition.dx, details.globalPosition.dy, details.globalPosition.dx, details.globalPosition.dy),
                items: [
                  PopupMenuItem(value: 'seek', child: Row(children: [const Icon(Icons.play_arrow, size: 14, color: Colors.white70), const SizedBox(width: 8), Text('Seek to $durationSec s', style: const TextStyle(fontSize: 11, color: Colors.white))])),
                  PopupMenuItem(value: 'color', child: Row(children: [const Icon(Icons.palette_outlined, size: 14, color: Colors.purpleAccent), const SizedBox(width: 8), Text('Fill Empty Space with Color ($durationSec s)', style: const TextStyle(fontSize: 11, color: Colors.white))])),
                  PopupMenuItem(value: 'image', child: Row(children: [const Icon(Icons.add_photo_alternate, size: 14, color: AppColors.clipBlue), const SizedBox(width: 8), Text('Fill Empty Space with Image ($durationSec s)', style: const TextStyle(fontSize: 11, color: Colors.white))])),
                ],
              );
              if (val == 'image') _pickImageToFill(ref);
              if (val == 'color') _fillColorMatte(ref);
              if (val == 'seek') onTap?.call();
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: isTargeted ? AppColors.clipBlue.withValues(alpha: 0.28) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isTargeted ? AppColors.clipBlueLight : Colors.white12,
                  width: isTargeted ? 1.5 : 0.8,
                ),
              ),
              child: Center(
                child: width > 55
                    ? Text(
                        isTargeted ? 'Drop Here' : '${durationSec}s',
                        style: TextStyle(
                          fontSize: 8.5,
                          color: isTargeted ? Colors.white : Colors.white30,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
