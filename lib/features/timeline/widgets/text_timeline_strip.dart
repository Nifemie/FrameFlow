import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../services/text_editing_service.dart';
import 'text_timeline_item.dart';

class TextTimelineStrip extends ConsumerWidget {
  final double pxPerSec;
  final double contentWidth;
  const TextTimelineStrip({
    super.key,
    required this.pxPerSec,
    required this.contentWidth,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlays = ref.watch(projectProvider.select((p) => p.textOverlays));
    final images = ref.watch(projectProvider.select((p) => p.images));
    final selectedId = ref.watch(selectedTextOverlayIdProvider);
    final playheadMs = ref.watch(playheadPositionProvider);

    final boundaries = <int>[];
    for (final img in images) {
      boundaries.add(img.startMs);
      boundaries.add(img.endMs);
    }

    return SizedBox(
      width: contentWidth,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final item in overlays)
            TextTimelineItem(
              key: ValueKey(item.id),
              item: item,
              pxPerSec: pxPerSec,
              isSelected: item.id == selectedId,
              boundaries: boundaries,
            ),
          Positioned(
            left: (playheadMs / 1000) * pxPerSec + 2, top: 4,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceLight,
                foregroundColor: AppColors.accentOrange,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                minimumSize: const Size(0, 24),
                side: const BorderSide(color: AppColors.accentOrange, width: 1.2),
              ),
              icon: const Icon(Icons.add, size: 12, color: AppColors.accentOrange),
              label: const Text('Add Text', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accentOrange)),
              onPressed: () {
                final newOverlay = TextEditingService.createDefaultOverlay(startMs: playheadMs);
                ref.read(projectProvider.notifier).addTextOverlay(newOverlay);
                ref.read(selectedTextOverlayIdProvider.notifier).state = newOverlay.id;
              },
            ),
          ),
        ],
      ),
    );
  }
}