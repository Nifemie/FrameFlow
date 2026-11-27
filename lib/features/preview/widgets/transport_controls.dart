import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';
import '../../../models/project.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/playback_controller.dart';
import '../../timestamps/widgets/live_stamp_button.dart';
import 'timecode_display.dart';

class TransportControls extends ConsumerWidget {
  const TransportControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(isPlayingProvider);
    final project = ref.watch(projectProvider);
    final totalMs = project.totalDurationMs;
    final playback = ref.read(playbackControllerProvider);
    final theme = ref.watch(themeProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      color: theme.viewportControlsColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 540;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Timecode readout
                  Consumer(
                    builder: (context, ref, _) {
                      final currentMs = ref.watch(playheadPositionProvider);
                      return TimecodeDisplay(currentMs: currentMs, totalMs: totalMs);
                    },
                  ),

                  const SizedBox(width: 8),

                  // Central Playback Controls & Live Stamp Button
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous, size: 18),
                        color: theme.iconColor('prevCut', theme.textColor),
                        tooltip: 'Previous Image Cut',
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        onPressed: () => playback.stepPrevious(),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.buttonColor,
                        ),
                        child: IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            size: 20,
                            color: theme.iconColor('playPause', Colors.white),
                          ),
                          padding: const EdgeInsets.all(7),
                          constraints: const BoxConstraints(),
                          tooltip: isPlaying ? 'Pause (Space)' : 'Play (Space)',
                          onPressed: () => playback.togglePlayPause(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.skip_next, size: 18),
                        color: theme.iconColor('nextCut', theme.textColor),
                        tooltip: 'Next Image Cut',
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        onPressed: () => playback.stepNext(),
                      ),
                      const SizedBox(width: 10),
                      // Live "Stamp Cut (M)" button
                      const LiveStampButton(),
                      const SizedBox(width: 8),
                      // Split Clip (S) button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.buttonColor.withValues(alpha: 0.18),
                          foregroundColor: theme.buttonColor,
                          side: BorderSide(color: theme.buttonColor, width: 1.2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                        onPressed: () {
                          final playheadMs = ref.read(playheadPositionProvider);
                          final selectedAudioId = ref.read(selectedAudioClipIdProvider);
                          final ok = ref.read(projectProvider.notifier).smartSplitAtPlayhead(playheadMs, selectedAudioId: selectedAudioId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                duration: const Duration(milliseconds: 1400),
                                backgroundColor: AppColors.surfaceLight,
                                content: Text(
                                  ok
                                      ? '✂️ Clip split at ${TimeParser.formatDetailed(playheadMs)}'
                                      : 'Place playhead inside a clip (>100ms from edges) to split',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ok ? AppColors.accentOrange : AppColors.errorRed,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                        icon: Icon(Icons.content_cut, size: 14, color: theme.iconColor('splitClip', theme.buttonColor)),
                        label: const Text(
                          'Split (S)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 8),

                  // Preview Quality Dropdown
                  Consumer(
                    builder: (context, ref, _) {
                      final quality = ref.watch(previewQualityProvider);
                      return Tooltip(
                        message: 'Preview Playback Quality',
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<PreviewQuality>(
                            value: quality,
                            dropdownColor: AppColors.surfaceLight,
                            icon: Icon(Icons.high_quality_outlined, size: 15, color: theme.iconColor('previewQuality', AppColors.textSecondary)),
                            style: TextStyle(fontSize: 11, color: theme.textColor),
                            items: PreviewQuality.values.map((q) {
                              return DropdownMenuItem(
                                value: q,
                                child: Text(isNarrow ? q.label.split(' ').first : q.label),
                              );
                            }).toList(),
                            onChanged: (q) {
                              if (q != null) {
                                ref.read(previewQualityProvider.notifier).state = q;
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(width: 8),

                  // Aspect Ratio Dropdown
                  DropdownButtonHideUnderline(
                    child: DropdownButton<VideoAspectRatio>(
                      value: project.aspectRatio,
                      dropdownColor: AppColors.surfaceLight,
                      icon: Icon(Icons.aspect_ratio, size: 15, color: theme.iconColor('aspectRatio', AppColors.textSecondary)),
                      style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                      items: VideoAspectRatio.values.map((ratio) {
                        return DropdownMenuItem(
                          value: ratio,
                          child: Text(isNarrow ? ratio.label.split(' ').first : ratio.label),
                        );
                      }).toList(),
                      onChanged: (ratio) {
                        if (ratio != null) {
                          ref.read(projectProvider.notifier).setAspectRatio(ratio);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
