import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../services/alignment_service.dart';

class AlignmentToolbar extends ConsumerWidget {
  const AlignmentToolbar({super.key});

  void _applyAlignment(WidgetRef ref, AlignmentType type) {
    final selectedId = ref.read(selectedImageIdProvider);
    final selectedIds = ref.read(selectedClipIdsProvider);
    final targetIds = selectedIds.isNotEmpty
        ? selectedIds
        : (selectedId != null ? {selectedId} : <String>{});

    if (targetIds.isEmpty) return;
    ref.read(projectProvider.notifier).applyAlignment(targetIds: targetIds, type: type);
  }

  Widget _btn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
          ),
          child: Icon(icon, size: 15, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ALIGNMENT & DISTRIBUTION',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.accentOrange,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),

        // Horizontal Row
        Row(
          children: [
            _btn(
              icon: Icons.align_horizontal_left_rounded,
              tooltip: 'Align Left',
              onTap: () => _applyAlignment(ref, AlignmentType.left),
            ),
            const SizedBox(width: 4),
            _btn(
              icon: Icons.align_horizontal_center_rounded,
              tooltip: 'Horizontal Center',
              onTap: () => _applyAlignment(ref, AlignmentType.horizontalCenter),
            ),
            const SizedBox(width: 4),
            _btn(
              icon: Icons.align_horizontal_right_rounded,
              tooltip: 'Align Right',
              onTap: () => _applyAlignment(ref, AlignmentType.right),
            ),
            const SizedBox(width: 8),
            _btn(
              icon: Icons.horizontal_distribute_rounded,
              tooltip: 'Distribute Horizontally',
              onTap: () => _applyAlignment(ref, AlignmentType.distributeHorizontal),
            ),
            const SizedBox(width: 4),
            _btn(
              icon: Icons.fit_screen_rounded,
              tooltip: 'Match Width',
              onTap: () => _applyAlignment(ref, AlignmentType.matchWidth),
            ),
          ],
        ),

        const SizedBox(height: 6),

        // Vertical Row & Center Canvas
        Row(
          children: [
            _btn(
              icon: Icons.align_vertical_top_rounded,
              tooltip: 'Align Top',
              onTap: () => _applyAlignment(ref, AlignmentType.top),
            ),
            const SizedBox(width: 4),
            _btn(
              icon: Icons.align_vertical_center_rounded,
              tooltip: 'Vertical Center',
              onTap: () => _applyAlignment(ref, AlignmentType.verticalCenter),
            ),
            const SizedBox(width: 4),
            _btn(
              icon: Icons.align_vertical_bottom_rounded,
              tooltip: 'Align Bottom',
              onTap: () => _applyAlignment(ref, AlignmentType.bottom),
            ),
            const SizedBox(width: 8),
            _btn(
              icon: Icons.vertical_distribute_rounded,
              tooltip: 'Distribute Vertically',
              onTap: () => _applyAlignment(ref, AlignmentType.distributeVertical),
            ),
            const SizedBox(width: 4),
            _btn(
              icon: Icons.add,
              tooltip: 'Align Center (Both Vertical & Horizontal)',
              onTap: () => _applyAlignment(ref, AlignmentType.centerCanvas),
            ),
          ],
        ),
      ],
    );
  }
}
