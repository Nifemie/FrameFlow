import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/project_provider.dart';
import '../../providers/selection_provider.dart';
import '../../services/playback_controller.dart';
import 'widgets/audio_waveform_strip.dart';
import 'widgets/playhead_needle.dart';
import 'widgets/timeline_clip.dart';
import 'widgets/timeline_ruler.dart';

class TimelineContainer extends ConsumerStatefulWidget {
  const TimelineContainer({super.key});

  @override
  ConsumerState<TimelineContainer> createState() => _TimelineContainerState();
}

class _TimelineContainerState extends ConsumerState<TimelineContainer> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSeek(int targetMs) {
    ref.read(playbackControllerProvider).seek(targetMs);
  }

  @override
  Widget build(BuildContext context) {
    final images = ref.watch(projectProvider.select((p) => p.images));
    final voiceOver = ref.watch(projectProvider.select((p) => p.voiceOver));
    final totalDurationMs = ref.watch(projectProvider.select((p) => p.totalDurationMs));
    final selectedId = ref.watch(selectedImageIdProvider);
    final playheadMs = ref.watch(playheadPositionProvider);
    final zoom = ref.watch(timelineZoomProvider);

    final pxPerSec = 40.0 * zoom;

    // Calculate sum of clip widths + margins to prevent RenderFlex overflow
    double clipsTotalWidth = 0;
    for (final img in images) {
      final baseWidth = (img.durationMs / 1000) * 40 * zoom;
      clipsTotalWidth += baseWidth.clamp(75.0, 600.0) + 3;
    }

    final durationWidth = ((totalDurationMs > 0 ? totalDurationMs : 10000) / 1000) * pxPerSec;
    final contentWidth = max(600.0, max(durationWidth, clipsTotalWidth + 40));
    final playheadX = (playheadMs / 1000) * pxPerSec;

    // Auto-scroll to keep playhead in view during playback
    ref.listen<int>(playheadPositionProvider, (prev, current) {
      if (!ref.read(isPlayingProvider) || !_scrollController.hasClients) return;
      final currentX = (current / 1000) * pxPerSec;
      final offset = _scrollController.offset;
      final viewWidth = _scrollController.position.viewportDimension;
      if (currentX > offset + viewWidth - 50) {
        _scrollController.animateTo(
          currentX - 50,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });

    return Container(
      height: 185,
      color: AppColors.background,
      child: Column(
        children: [
          // Synchronized Scroll Area
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: contentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ruler
                        TimelineRuler(
                          totalDurationMs: totalDurationMs,
                          pixelsPerSecond: pxPerSec,
                          onSeek: _handleSeek,
                        ),
                        const SizedBox(height: 6),

                        // Track 1: Images Track (min size prevents overflow)
                        SizedBox(
                          height: 70,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: images.map((img) {
                              return TimelineClip(
                                item: img,
                                isSelected: img.id == selectedId,
                                zoomScale: zoom,
                                onTap: () {
                                  ref.read(selectedImageIdProvider.notifier).state = img.id;
                                  _handleSeek(img.startMs);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Track 2: Audio Track
                        if (voiceOver != null)
                          AudioWaveformStrip(
                            voiceOver: voiceOver,
                            width: (voiceOver.durationMs / 1000) * pxPerSec,
                          ),
                      ],
                    ),
                  ),

                  // Draggable Orange Playhead Needle
                  PlayheadNeedle(
                    positionX: playheadX,
                    height: 160,
                    onDragUpdate: (deltaX) {
                      final deltaMs = ((deltaX / pxPerSec) * 1000).round();
                      _handleSeek(playheadMs + deltaMs);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
