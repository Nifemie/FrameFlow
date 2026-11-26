import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/theme_provider.dart';
import 'advanced_color_picker_dialog.dart';
import 'icon_colors_dialog.dart';

class ThemeCustomizerDialog extends ConsumerWidget {
  const ThemeCustomizerDialog({super.key});

  Future<void> _promptSaveTheme(BuildContext context, WidgetRef ref, StudioThemeColors current) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Save Custom Theme', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(fontSize: 13, color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Theme Name',
            hintText: 'e.g. Midnight Blue, Neon Studio',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      final saved = ref.read(savedThemesProvider.notifier).saveTheme(name, current);
      ref.read(themeProvider.notifier).applySavedTheme(saved);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);
    final savedThemes = ref.watch(savedThemesProvider);
    final savedNotifier = ref.read(savedThemesProvider.notifier);

    final items = <({String key, String label, Color color})>[
      (key: 'topPanel', label: 'Top Panel', color: theme.topPanelColor),
      (key: 'leftPanel', label: 'Left Panel', color: theme.leftPanelColor),
      (key: 'rightPanel', label: 'Right Panel', color: theme.rightPanelColor),
      (key: 'viewport', label: 'Viewport', color: theme.viewportColor),
      (key: 'viewportControls', label: 'Viewport Controls', color: theme.viewportControlsColor),
      (key: 'timeline', label: 'Timeline & Background', color: theme.timelineColor),
      (key: 'text', label: 'Text Colour', color: theme.textColor),
      (key: 'button', label: 'Button Colour', color: theme.buttonColor),
      (key: 'playhead', label: 'Playhead Colour', color: theme.playheadColor),
      (key: 'export', label: 'Export Colour', color: theme.exportColor),
    ];

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Icon(Icons.palette_outlined, size: 18, color: theme.buttonColor),
          const SizedBox(width: 8),
          Text('Customize Appearance', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.textColor)),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Theme Presets', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _PresetCard(
                      title: 'Default',
                      subtitle: 'Studio Charcoal & Orange',
                      bgPreview: StudioThemeColors.defaultTheme.viewportColor,
                      surfacePreview: StudioThemeColors.defaultTheme.topPanelColor,
                      accentPreview: StudioThemeColors.defaultTheme.buttonColor,
                      isSelected: theme.presetName == 'default',
                      onTap: notifier.applyDefaultTheme,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PresetCard(
                      title: 'Black Theme',
                      subtitle: 'Pure AMOLED Black',
                      bgPreview: StudioThemeColors.blackTheme.viewportColor,
                      surfacePreview: StudioThemeColors.blackTheme.topPanelColor,
                      accentPreview: StudioThemeColors.blackTheme.buttonColor,
                      isSelected: theme.presetName == 'black',
                      onTap: notifier.applyBlackTheme,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Saved Custom Themes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  TextButton.icon(
                    onPressed: () => _promptSaveTheme(context, ref, theme),
                    icon: Icon(Icons.bookmark_add_outlined, size: 13, color: theme.buttonColor),
                    label: Text('Save Current Theme', style: TextStyle(fontSize: 11, color: theme.buttonColor)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              if (savedThemes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('No saved custom themes yet. Customize colors below and click "Save Current Theme".', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                )
              else ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: savedThemes.map((saved) {
                    final isSelected = theme.presetName == 'saved:${saved.id}';
                    return InkWell(
                      onTap: () => notifier.applySavedTheme(saved),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? saved.colors.buttonColor : AppColors.surfaceBorder,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: saved.colors.viewportColor, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                            ),
                            const SizedBox(width: 3),
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: saved.colors.buttonColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(saved.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => savedNotifier.deleteTheme(saved.id),
                              child: const Icon(Icons.close, size: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.surfaceBorder),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => const IconColorsDialog(),
                ),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.buttonColor.withValues(alpha: 0.6), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.apps, size: 17, color: theme.buttonColor),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Icons', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('Customize individual colors for all software icons', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Custom Colors (Wheel, HSL, RGB & Recommended)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ...items.map((item) => _ColorSettingRow(
                    label: item.label,
                    color: item.color,
                    onColorPicked: (c) => notifier.updateColor(item.key, c),
                  )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: notifier.applyDefaultTheme,
          child: const Text('Reset to Default', style: TextStyle(color: AppColors.textSecondary)),
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

class _PresetCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color bgPreview;
  final Color surfacePreview;
  final Color accentPreview;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetCard({
    required this.title,
    required this.subtitle,
    required this.bgPreview,
    required this.surfacePreview,
    required this.accentPreview,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? accentPreview : AppColors.surfaceBorder, width: isSelected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 26,
              decoration: BoxDecoration(
                color: bgPreview,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                children: [
                  Container(height: 6, color: surfacePreview),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      width: 10,
                      height: 4,
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: accentPreview, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, size: 15, color: accentPreview),
          ],
        ),
      ),
    );
  }
}

class _ColorSettingRow extends StatelessWidget {
  final String label;
  final Color color;
  final ValueChanged<Color> onColorPicked;

  const _ColorSettingRow({
    required this.label,
    required this.color,
    required this.onColorPicked,
  });

  String _hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => AdvancedColorPickerDialog(
            title: label,
            initialColor: color,
            onColorChanged: onColorPicked,
          ),
        ),
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
              Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white))),
              Text(_hex(color), style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(width: 10),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
