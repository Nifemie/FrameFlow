import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/asset_animation.dart';
import '../../../services/animation_library.dart';

class RandomisationPresetPicker extends StatefulWidget {
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  const RandomisationPresetPicker({
    super.key,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  State<RandomisationPresetPicker> createState() => _RandomisationPresetPickerState();
}

class _RandomisationPresetPickerState extends State<RandomisationPresetPicker> {
  AnimationCategory _currentCat = AnimationCategory.entrance;

  void _toggleAllInCurrent(bool select) {
    final catPresets = AnimationLibrary.byCategory(_currentCat);
    final updated = Set<String>.from(widget.selectedIds);
    for (final p in catPresets) {
      if (select) { updated.add(p.id); } else { updated.remove(p.id); }
    }
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final catPresets = AnimationLibrary.byCategory(_currentCat);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: AnimationCategory.values.map((cat) {
              final isSel = cat == _currentCat;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(cat.label, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : AppColors.textMuted)),
                  selected: isSel,
                  selectedColor: AppColors.accentBlue,
                  backgroundColor: AppColors.surfaceBorder,
                  onSelected: (_) => setState(() => _currentCat = cat),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${widget.selectedIds.length} Total Selected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.accentBlue)),
            Row(
              children: [
                TextButton(onPressed: () => _toggleAllInCurrent(true), child: const Text('Select Category', style: TextStyle(fontSize: 11))),
                TextButton(onPressed: () => _toggleAllInCurrent(false), child: const Text('Deselect', style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.surfaceBorder)),
            child: ListView.separated(
              itemCount: catPresets.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.surfaceBorder),
              itemBuilder: (context, index) {
                final preset = catPresets[index];
                final isChecked = widget.selectedIds.contains(preset.id);
                return CheckboxListTile(
                  dense: true,
                  value: isChecked,
                  activeColor: AppColors.accentBlue,
                  title: Row(
                    children: [
                      Icon(preset.icon, size: 16, color: isChecked ? AppColors.accentBlue : AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text(preset.name, style: TextStyle(fontSize: 12, fontWeight: isChecked ? FontWeight.bold : FontWeight.normal, color: Colors.white)),
                    ],
                  ),
                  subtitle: Text(preset.description, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  onChanged: (val) {
                    final updated = Set<String>.from(widget.selectedIds);
                    if (val == true) { updated.add(preset.id); } else { updated.remove(preset.id); }
                    widget.onChanged(updated);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
