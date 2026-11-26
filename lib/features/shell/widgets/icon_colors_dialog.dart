import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/theme_provider.dart';
import 'advanced_color_picker_dialog.dart';

class IconColorsDialog extends ConsumerWidget {
  const IconColorsDialog({super.key});

  String _hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);

    final groups = <String, List<StudioIconDef>>{};
    for (final def in StudioIconCatalog.all) {
      groups.putIfAbsent(def.group, () => []).add(def);
    }

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Icon(Icons.apps, size: 18, color: theme.buttonColor),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Customize Icon Colors', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        height: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final entry in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 6),
                  child: Text(
                    entry.key,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                ),
                for (final def in entry.value)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: InkWell(
                      onTap: () {
                        final current = theme.iconColor(def.id, def.defaultColor);
                        showDialog<void>(
                          context: context,
                          builder: (_) => AdvancedColorPickerDialog(
                            title: 'Icon: ${def.label}',
                            initialColor: current,
                            onColorChanged: (c) => notifier.updateIconColor(def.id, c),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.surfaceBorder, width: 0.7),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              def.icon,
                              size: 18,
                              color: theme.iconColor(def.id, def.defaultColor),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(def.label, style: const TextStyle(fontSize: 12, color: Colors.white)),
                            ),
                            Text(
                              _hex(theme.iconColor(def.id, def.defaultColor)),
                              style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, color: AppColors.textMuted),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: theme.iconColor(def.id, def.defaultColor),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.surfaceBorder),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: notifier.resetIconColors,
          child: const Text('Reset Icons', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: theme.buttonColor, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
