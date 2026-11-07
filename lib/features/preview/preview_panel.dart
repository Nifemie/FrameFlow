import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/image_item.dart';
import '../../providers/project_provider.dart';
import '../../providers/selection_provider.dart';
import '../../services/timing_engine.dart';
import 'widgets/preview_canvas.dart';
import 'widgets/transport_controls.dart';

class PreviewPanel extends ConsumerWidget {
  const PreviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    final playheadMs = ref.watch(playheadPositionProvider);

    // Compute which image should be displayed on the canvas
    ImageItem? activeImage;
    if (project.images.isNotEmpty) {
      final activeIndex = TimingEngine.findActiveImageIndex(project.images, playheadMs);
      if (activeIndex >= 0 && activeIndex < project.images.length) {
        activeImage = project.images[activeIndex];
      }
    }

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Main Preview Monitor Area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PreviewCanvas(
                activeImage: activeImage,
                aspectRatio: project.aspectRatio,
              ),
            ),
          ),

          // Transport Controls Strip
          const TransportControls(),
        ],
      ),
    );
  }
}
