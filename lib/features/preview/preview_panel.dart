import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../models/image_item.dart';
import '../../models/timeline_track_item.dart';
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

    final videoTracks = project.effectiveTracks.where((t) => t.isVideoOrBg).toList();
    videoTracks.sort((a, b) {
      int weight(TimelineTrackItem t) {
        if (t.type == TrackType.backgroundUnderlay) return 0;
        if (t.type == TrackType.mainVideo) return 1;
        return 2;
      }
      final wDiff = weight(a).compareTo(weight(b));
      if (wDiff != 0) return wDiff;
      return a.orderIndex.compareTo(b.orderIndex);
    });

    final activeLayers = <({ImageItem image, bool isVisible})>[];
    for (final tr in videoTracks) {
      final trImages = project.imagesForTrack(tr.id);
      if (trImages.isNotEmpty) {
        final idx = TimingEngine.findActiveImageIndex(trImages, playheadMs);
        if (idx >= 0 && idx < trImages.length) {
          activeLayers.add((image: trImages[idx], isVisible: tr.isVisible));
        }
      }
    }

    final isTextVisible = project.isTrackVisible('track_t1');

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PreviewCanvas(
                activeLayers: activeLayers,
                aspectRatio: project.aspectRatio,
                hasMedia: project.images.isNotEmpty || project.voiceOver != null,
                textOverlays: project.textOverlays,
                playheadMs: playheadMs,
                isTextTrackVisible: isTextVisible,
              ),
            ),
          ),
          const TransportControls(),
        ],
      ),
    );
  }
}
