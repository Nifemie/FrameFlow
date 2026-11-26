import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/theme_provider.dart';

class ThemeCustomizerDialog extends ConsumerWidget {
  const ThemeCustomizerDialog({super.key});

  static const _surfaceSwatches = <Color>[
    Color(0xFF000000),
    Color(0xFF050505),
    Color(0xFF0C0D11),
    Color(0xFF13151C),
    Color(0xFF181B24),
    Color(0xFF1E293B),
    Color(0xFF141824),
    Color(0xFF1A1625),
    Color(0xFF13201B),
    Color(0xFF211616),
    Color(0xFF282D3C),
    Color(0xFF334155),
  ];

  static const _accentSwatches = <Color>[
    Color(0xFFFF6600),
    Color(0xFFFF7A1A),
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFEF4444),
    Color(0xFFEAB308),
    Color(0xFFF3F4F6),
    Color(0xFFFFFFFF),
    Color(0xFF9CA3AF),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);

    final items = <({String key, String label, Color color, bool isAccent})>[
      (key: 'topPanel', label: 'Top Panel', color: theme.topPanelColor, isAccent: false),
      (key: 'leftPanel', label: 'Left Panel', color: theme.leftPanelColor, isAccent: false),
      (key: 'rightPanel', label: 'Right Panel', color: theme.rightPanelColor, isAccent: false),
      (key: 'viewport', label: 'Viewport', color: theme.viewportColor, isAccent: false),
      (key: 'viewportControls', label: 'Viewport Controls', color: theme.viewportControlsColor, isAccent: false),
      (key: 'timeline', label: 'Timeline & Background', color: theme.timelineColor, isAccent: false),
      (key: 'text', label: 'Text Colour', color: theme.textColor, isAccent: true),
      (key: 'button', label: 'Button Colour', color: theme.buttonColor, isAccent: true),
      (key: 'playhead', label: 'Playhead Colour', color: theme.playheadColor, isAccent: true),
      (key: 'export', label: 'Export Colour', color: theme.exportColor, isAccent: true),
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
        width: 440,
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
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.surfaceBorder),
              const SizedBox(height: 12),
              const Text('Custom Colors', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ...items.map((item) => _ColorSettingRow(
                    label: item.label,
                    color: item.color,
                    swatches: item.isAccent ? _accentSwatches : _surfaceSwatches,
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
  final List<Color> swatches;
  final ValueChanged<Color> onColorPicked;

  const _ColorSettingRow({
    required this.label,
    required this.color,
    required this.swatches,
    required this.onColorPicked,
  });

  String _hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  Future<void> _openPicker(BuildContext context) async {
    final hexCtrl = TextEditingController(text: _hex(color));
    Color tempColor = color;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: swatches.map((s) {
                    final selected = s.toARGB32() == tempColor.toARGB32();
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          tempColor = s;
                          hexCtrl.text = _hex(s);
                        });
                        onColorPicked(s);
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: s,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: selected ? Colors.white : AppColors.surfaceBorder,
                            width: selected ? 2.2 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: hexCtrl,
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Hex Color (e.g. #FF6600)',
                    prefixIcon: Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tempColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                    ),
                  ),
                  onChanged: (val) {
                    final clean = val.trim().replaceAll('#', '');
                    if (clean.length == 6) {
                      final parsed = int.tryParse('FF$clean', radix: 16);
                      if (parsed != null) {
                        final next = Color(parsed);
                        setState(() => tempColor = next);
                        onColorPicked(next);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _openPicker(context),
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
