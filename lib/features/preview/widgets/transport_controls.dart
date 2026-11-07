import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/project.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../services/playback_controller.dart';
import '../../timestamps/widgets/live_stamp_button.dart';
import 'timecode_display.dart';

class TransportControls extends ConsumerWidget {
  const TransportControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(isPlayingProvider);
    final currentMs = ref.watch(playheadPositionProvider);
    final project = ref.watch(projectProvider);
    final totalMs = project.totalDurationMs;
    final playback = ref.read(playbackControllerProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Timecode readout
          TimecodeDisplay(currentMs: currentMs, totalMs: totalMs),

          // Central Playback Controls & Live Stamp Button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous, size: 20),
                color: AppColors.textPrimary,
                tooltip: 'Previous Image Cut',
                onPressed: () => playback.stepPrevious(),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.clipBlue,
                ),
                child: IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 22,
                    color: Colors.white,
                  ),
                  tooltip: isPlaying ? 'Pause (Space)' : 'Play (Space)',
                  onPressed: () => playback.togglePlayPause(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.skip_next, size: 20),
                color: AppColors.textPrimary,
                tooltip: 'Next Image Cut',
                onPressed: () => playback.stepNext(),
              ),
              const SizedBox(width: 14),
              // Live "Stamp Cut (M)" button
              const LiveStampButton(),
            ],
          ),

          // Aspect Ratio Dropdown
          DropdownButtonHideUnderline(
            child: DropdownButton<VideoAspectRatio>(
              value: project.aspectRatio,
              dropdownColor: AppColors.surfaceLight,
              icon: const Icon(Icons.aspect_ratio, size: 16, color: AppColors.textSecondary),
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              items: VideoAspectRatio.values.map((ratio) {
                return DropdownMenuItem(
                  value: ratio,
                  child: Text(ratio.label),
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
    );
  }
}
