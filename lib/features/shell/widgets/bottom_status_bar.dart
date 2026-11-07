import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';

class BottomStatusBar extends ConsumerWidget {
  const BottomStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    final zoom = ref.watch(timelineZoomProvider);

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Timeline Scale / Zoom Slider
          const Icon(Icons.zoom_out, size: 14, color: AppColors.textMuted),
          SizedBox(
            width: 100,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                trackHeight: 2,
                activeTrackColor: AppColors.clipBlue,
                inactiveTrackColor: AppColors.surfaceBorder,
              ),
              child: Slider(
                value: zoom,
                min: 0.5,
                max: 3.0,
                onChanged: (val) {
                  ref.read(timelineZoomProvider.notifier).state = val;
                },
              ),
            ),
          ),
          const Icon(Icons.zoom_in, size: 14, color: AppColors.textMuted),

          const SizedBox(width: 24),
          const VerticalDivider(width: 1, indent: 8, endIndent: 8, color: AppColors.surfaceBorder),
          const SizedBox(width: 16),

          // Total duration
          Text(
            'Total Length: ${TimeParser.formatStandard(project.totalDurationMs)}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),

          const Spacer(),

          // FPS & Resolution info
          Text(
            '${project.resolution.label} • ${project.fps} FPS',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
