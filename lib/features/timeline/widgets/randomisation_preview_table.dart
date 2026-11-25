import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/animation_preset.dart';
import '../../../services/animation_library.dart';
import '../../../services/animation_randomisation_engine.dart';

class RandomisationPreviewTable extends StatelessWidget {
  final List<ProposedAssignment> assignments;
  final ValueChanged<List<ProposedAssignment>> onAssignmentsChanged;

  const RandomisationPreviewTable({
    super.key,
    required this.assignments,
    required this.onAssignmentsChanged,
  });

  void _updateRow(int index, {AnimationPreset? newPreset, bool? isLocked}) {
    final updated = List<ProposedAssignment>.from(assignments);
    updated[index] = updated[index].copyWith(preset: newPreset, isLocked: isLocked);
    onAssignmentsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return const Center(child: Text('No matching assets found in target scope', style: TextStyle(color: AppColors.textMuted)));
    }

    return Container(
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.surfaceBorder)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppColors.surfaceBorder.withValues(alpha: 0.5),
            child: const Row(
              children: [
                SizedBox(width: 32, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                Expanded(flex: 3, child: Text('Asset', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                Expanded(flex: 4, child: Text('Assigned Animation', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
                SizedBox(width: 40, child: Text('Lock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted))),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.surfaceBorder),
          Expanded(
            child: ListView.separated(
              itemCount: assignments.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.surfaceBorder),
              itemBuilder: (context, idx) {
                final row = assignments[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 32, child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted))),
                      Expanded(
                        flex: 3,
                        child: Text(
                          row.asset.displayName,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: row.preset?.id,
                            isDense: true,
                            dropdownColor: AppColors.cardSurface,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('(Unchanged)', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
                              ),
                              ...AnimationLibrary.presets.map((p) => DropdownMenuItem<String?>(
                                value: p.id,
                                child: Row(
                                  children: [
                                    Icon(p.icon, size: 14, color: AppColors.accentBlue),
                                    const SizedBox(width: 6),
                                    Text(p.name, style: const TextStyle(fontSize: 11, color: Colors.white)),
                                  ],
                                ),
                              )),
                            ],
                            onChanged: (newId) {
                              if (newId == null) {
                                _updateRow(idx, newPreset: null);
                              } else {
                                final p = AnimationLibrary.findById(newId);
                                if (p != null) _updateRow(idx, newPreset: p);
                              }
                            },
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: IconButton(
                          iconSize: 16,
                          padding: EdgeInsets.zero,
                          icon: Icon(row.isLocked ? Icons.lock : Icons.lock_open, color: row.isLocked ? AppColors.warningYellow : AppColors.textMuted),
                          onPressed: () => _updateRow(idx, isLocked: !row.isLocked),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
