import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../timeline/services/timeline_zoom_controller.dart';

class BottomStatusBar extends ConsumerWidget {
  const BottomStatusBar({super.key});

  void _fitTimeline(BuildContext context, WidgetRef ref) {
    final totalDurationMs = ref.read(projectProvider).totalDurationMs;
    final screenWidth = MediaQuery.of(context).size.width;
    // Main layout timeline viewport width is roughly screenWidth - 64 (margins)
    final fitZoom = TimelineZoomController.calculateFitZoom(
      totalDurationMs: totalDurationMs,
      viewportWidth: screenWidth - 64,
    );
    ref.read(timelineZoomProvider.notifier).state = fitZoom;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    final zoom = ref.watch(timelineZoomProvider);
    final zoomPercent = (zoom * 100).round();
    final timelineColor = ref.watch(themeProvider.select((t) => t.timelineColor));

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: timelineColor,
        border: const Border(top: BorderSide(color: AppColors.surfaceBorder, width: 1)),
      ),
      child: Row(
        children: [
          // Zoom out button
          IconButton(
            icon: const Icon(Icons.remove, size: 14, color: AppColors.textMuted),
            splashRadius: 14,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            tooltip: 'Zoom Out (-)',
            onPressed: () {
              final newZ = (zoom - 0.25).clamp(TimelineZoomController.minZoom, TimelineZoomController.maxZoom);
              ref.read(timelineZoomProvider.notifier).state = newZ;
            },
          ),

          // Zoom Slider (0.2 to 5.0)
          SizedBox(
            width: 90,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                trackHeight: 2,
                activeTrackColor: AppColors.clipBlue,
                inactiveTrackColor: AppColors.surfaceBorder,
              ),
              child: Slider(
                value: zoom,
                min: TimelineZoomController.minZoom,
                max: TimelineZoomController.maxZoom,
                onChanged: (val) => ref.read(timelineZoomProvider.notifier).state = val,
              ),
            ),
          ),

          // Zoom in button
          IconButton(
            icon: const Icon(Icons.add, size: 14, color: AppColors.textMuted),
            splashRadius: 14,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            tooltip: 'Zoom In (+)',
            onPressed: () {
              final newZ = (zoom + 0.25).clamp(TimelineZoomController.minZoom, TimelineZoomController.maxZoom);
              ref.read(timelineZoomProvider.notifier).state = newZ;
            },
          ),

          const SizedBox(width: 4),
          // Percentage badge / Reset button
          InkWell(
            onTap: () => ref.read(timelineZoomProvider.notifier).state = 1.0,
            borderRadius: BorderRadius.circular(3),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                '$zoomPercent%',
                style: const TextStyle(fontSize: 10, fontFamily: 'Consolas', color: AppColors.textSecondary),
              ),
            ),
          ),

          const SizedBox(width: 6),
          // Fit timeline button
          IconButton(
            icon: const Icon(Icons.fit_screen_rounded, size: 14, color: AppColors.textMuted),
            splashRadius: 14,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
            tooltip: 'Fit Timeline to Screen (Home)',
            onPressed: () => _fitTimeline(context, ref),
          ),

          const SizedBox(width: 16),
          const VerticalDivider(width: 1, indent: 8, endIndent: 8, color: AppColors.surfaceBorder),
          const SizedBox(width: 16),

          Text(
            'Total Length: ${TimeParser.formatStandard(project.totalDurationMs)}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),

          const Spacer(),

          Text(
            '${project.resolution.label} • ${project.fps} FPS',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
