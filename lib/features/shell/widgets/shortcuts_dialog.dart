import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/shortcut_provider.dart';

class ShortcutsDialog extends ConsumerWidget {
  const ShortcutsDialog({super.key});

  static const _availableKeys = [
    LogicalKeyboardKey.keyS, LogicalKeyboardKey.keyC, LogicalKeyboardKey.keyB, LogicalKeyboardKey.keyX,
    LogicalKeyboardKey.keyM, LogicalKeyboardKey.keyT, LogicalKeyboardKey.keyP, LogicalKeyboardKey.keyK,
    LogicalKeyboardKey.space, LogicalKeyboardKey.delete, LogicalKeyboardKey.backspace,
  ];

  void _pickKey(BuildContext context, WidgetRef ref, String title, LogicalKeyboardKey current, void Function(LogicalKeyboardKey) onSelect) {
    showDialog(
      context: context,
      builder: (_) => SimpleDialog(
        backgroundColor: AppColors.surface,
        title: Text('Choose Key for $title', style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
        children: _availableKeys.map((k) {
          final label = ref.read(shortcutProvider).keyLabel(k);
          final isSelected = k == current;
          return SimpleDialogOption(
            onPressed: () { onSelect(k); Navigator.of(context).pop(); },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: isSelected ? AppColors.clipBlueLight : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                if (isSelected) const Icon(Icons.check, size: 14, color: AppColors.clipBlueLight),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = ref.watch(shortcutProvider);
    final notifier = ref.read(shortcutProvider.notifier);

    final shortcuts = [
      ('Split Clip at Playhead', cfg.keyLabel(cfg.splitKey), 'Editing (Customizable)', () => _pickKey(context, ref, 'Split Clip', cfg.splitKey, notifier.setSplitKey)),
      ('Stamp Cut Point', cfg.keyLabel(cfg.stampKey), 'Editing (Customizable)', () => _pickKey(context, ref, 'Stamp Cut', cfg.stampKey, notifier.setStampKey)),
      ('Play / Pause', cfg.keyLabel(cfg.playPauseKey), 'Playback (Customizable)', () => _pickKey(context, ref, 'Play / Pause', cfg.playPauseKey, notifier.setPlayPauseKey)),
      ('Delete Selected Clip', cfg.keyLabel(cfg.deleteKey), 'Editing (Customizable)', () => _pickKey(context, ref, 'Delete Clip', cfg.deleteKey, notifier.setDeleteKey)),
      ('Undo', 'Ctrl + Z', 'History', null),
      ('Redo', 'Ctrl + Y / Shift + Ctrl + Z', 'History', null),
      ('Save Project', 'Ctrl + S', 'Project', null),
      ('New Project', 'Ctrl + N', 'Project', null),
      ('Export Video', 'Ctrl + E', 'Project', null),
      ('Duplicate Clip', 'Ctrl + D', 'Editing', null),
      ('Zoom In / Out', '+ / -', 'Timeline', null),
      ('Fit Timeline', 'Home', 'Timeline', null),
      ('Previous / Next Image', 'Left / Right Arrow', 'Playback', null),
    ];

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(children: [Icon(Icons.keyboard, color: AppColors.clipBlueLight, size: 20), SizedBox(width: 8), Text('Keyboard Shortcuts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary))]),
          TextButton(onPressed: notifier.resetDefaults, child: const Text('Reset Defaults', style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
        ],
      ),
      content: SizedBox(
        width: 480, height: 380,
        child: ListView.separated(
          itemCount: shortcuts.length,
          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.surfaceBorder),
          itemBuilder: (context, i) {
            final (action, keyCombo, cat, onEdit) = shortcuts[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                children: [
                  Expanded(child: Text(action, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(2)),
                    child: Text(cat, style: TextStyle(fontSize: 8.5, color: onEdit != null ? AppColors.accentOrange : AppColors.textMuted)),
                  ),
                  InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: onEdit != null ? AppColors.clipBlue.withValues(alpha: 0.25) : AppColors.surfaceBorder.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: onEdit != null ? AppColors.clipBlueLight : AppColors.surfaceBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(keyCombo, style: const TextStyle(fontSize: 11, fontFamily: 'Consolas', fontWeight: FontWeight.bold, color: AppColors.clipBlueLight)),
                          if (onEdit != null) ...[const SizedBox(width: 4), const Icon(Icons.edit, size: 10, color: AppColors.clipBlueLight)],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.clipBlue),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ],
    );
  }
}