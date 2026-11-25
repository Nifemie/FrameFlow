import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/randomisation_config.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../services/animation_randomisation_engine.dart';
import 'randomisation_preset_picker.dart';
import 'randomisation_preview_table.dart';

class AnimationRandomisationDialog extends ConsumerStatefulWidget {
  const AnimationRandomisationDialog({super.key});

  @override
  ConsumerState<AnimationRandomisationDialog> createState() => _AnimationRandomisationDialogState();
}

class _AnimationRandomisationDialogState extends ConsumerState<AnimationRandomisationDialog> {
  late RandomisationConfig _config;
  List<ProposedAssignment> _previewAssignments = [];

  @override
  void initState() {
    super.initState();
    final selectedId = ref.read(selectedImageIdProvider);
    _config = RandomisationConfig(
      selectedPresetIds: {'zoomIn', 'slideInLeft', 'fadeIn', 'bounceIn', 'rotateIn'},
      targetScope: selectedId != null ? RandomisationTargetScope.selectedAssets : RandomisationTargetScope.allImages,
      selectedAssetIds: selectedId != null ? {selectedId} : {},
      seed: Random().nextInt(10000),
    );
    _regenerateAssignments();
  }

  void _regenerateAssignments({int? newSeed}) {
    final project = ref.read(projectProvider);
    if (newSeed != null) _config = _config.copyWith(seed: newSeed);
    setState(() {
      _previewAssignments = AnimationRandomisationEngine.generateAssignments(
        project: project,
        config: _config,
      );
    });
  }

  void _applyAndClose() {
    if (_previewAssignments.isNotEmpty) {
      ref.read(projectProvider.notifier).applyAnimationRandomisation(_previewAssignments);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.cardSurface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.surfaceBorder)),
      child: Container(
        width: 880, height: 600,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.accentBlue, size: 22),
                const SizedBox(width: 8),
                const Text('Intelligent Animation Randomisation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const Divider(height: 20, color: AppColors.surfaceBorder),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: RandomisationPresetPicker(
                      selectedIds: _config.selectedPresetIds,
                      onChanged: (ids) {
                        setState(() => _config = _config.copyWith(selectedPresetIds: ids));
                        _regenerateAssignments();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  const VerticalDivider(width: 1, color: AppColors.surfaceBorder),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildControls(),
                        const SizedBox(height: 12),
                        const Text('Proposed Assignments Preview', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        Expanded(
                          child: RandomisationPreviewTable(
                            assignments: _previewAssignments,
                            onAssignmentsChanged: (up) => setState(() => _previewAssignments = up),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 20, color: AppColors.surfaceBorder),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.casino_outlined, size: 16),
                  label: const Text('Regenerate'),
                  onPressed: () => _regenerateAssignments(newSeed: Random().nextInt(10000)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentBlue, foregroundColor: Colors.white),
                  icon: const Icon(Icons.check, size: 16),
                  label: Text('Apply to ${_previewAssignments.where((a) => a.preset != null).length} of ${_previewAssignments.length} Assets'),
                  onPressed: _previewAssignments.isEmpty ? null : _applyAndClose,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<RandomisationDistributionMode>(
                initialValue: _config.distributionMode,
                isDense: true,
                decoration: const InputDecoration(labelText: 'Distribution Mode', isDense: true),
                dropdownColor: AppColors.cardSurface,
                items: RandomisationDistributionMode.values.map((m) => DropdownMenuItem(value: m, child: Text(m.label, style: const TextStyle(fontSize: 11)))).toList(),
                onChanged: (m) {
                  if (m != null) { setState(() => _config = _config.copyWith(distributionMode: m)); _regenerateAssignments(); }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<RandomisationTargetScope>(
                initialValue: _config.targetScope,
                isDense: true,
                decoration: const InputDecoration(labelText: 'Target Scope', isDense: true),
                dropdownColor: AppColors.cardSurface,
                items: RandomisationTargetScope.values.map((s) => DropdownMenuItem(value: s, child: Text(s.label, style: const TextStyle(fontSize: 11)))).toList(),
                onChanged: (s) {
                  if (s != null) { setState(() => _config = _config.copyWith(targetScope: s)); _regenerateAssignments(); }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('Coverage: ${_config.percentage.round()}% (${_previewAssignments.where((a) => a.preset != null).length} of ${_previewAssignments.length} assets)', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            Expanded(
              child: Slider(
                value: _config.percentage, min: 0, max: 100, divisions: 20, activeColor: AppColors.accentBlue,
                onChanged: (v) { setState(() => _config = _config.copyWith(percentage: v)); _regenerateAssignments(); },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
