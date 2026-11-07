import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_parser.dart';
import '../../models/image_item.dart';
import '../../providers/project_provider.dart';
import '../../providers/selection_provider.dart';
import 'widgets/fit_mode_selector.dart';
import 'widgets/timestamp_editor.dart';

class PropertiesPanel extends ConsumerWidget {
  const PropertiesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedImageIdProvider);
    final project = ref.watch(projectProvider);

    ImageItem? selectedItem;
    bool isLast = false;

    if (selectedId != null && project.images.isNotEmpty) {
      final index = project.images.indexWhere((img) => img.id == selectedId);
      if (index != -1) {
        selectedItem = project.images[index];
        isLast = (index == project.images.length - 1);
      }
    }

    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          left: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      child: selectedItem == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select an image to edit its timing and display options',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Header
                Text(
                  'Clip #${selectedItem.orderIndex + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.clipBlueLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  selectedItem.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.surfaceBorder),
                const SizedBox(height: 12),

                // Timing summary chips
                Row(
                  children: [
                    _buildStatChip('Start', TimeParser.formatStandard(selectedItem.startMs)),
                    const SizedBox(width: 8),
                    _buildStatChip('End', TimeParser.formatStandard(selectedItem.endMs)),
                    const SizedBox(width: 8),
                    _buildStatChip('Duration', '${(selectedItem.durationMs / 1000).toStringAsFixed(1)}s'),
                  ],
                ),

                const SizedBox(height: 16),
                TimestampEditor(
                  item: selectedItem,
                  isLastImage: isLast,
                  hasVoiceOver: project.voiceOver != null,
                ),

                const SizedBox(height: 20),
                const Divider(height: 1, color: AppColors.surfaceBorder),
                const SizedBox(height: 16),

                FitModeSelector(
                  currentMode: selectedItem.fitMode,
                  onModeChanged: (mode) {
                    ref.read(projectProvider.notifier).updateFitMode(selectedItem!.id, mode);
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
