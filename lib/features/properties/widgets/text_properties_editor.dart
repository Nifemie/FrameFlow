import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/text_overlay_item.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../services/font_loader_service.dart';
import '../../../services/timing_engine.dart';
import 'inline_color_picker.dart';

class TextPropertiesEditor extends ConsumerStatefulWidget {
  final TextOverlayItem item;
  const TextPropertiesEditor({super.key, required this.item});

  @override
  ConsumerState<TextPropertiesEditor> createState() => _TextPropertiesEditorState();
}

class _TextPropertiesEditorState extends ConsumerState<TextPropertiesEditor> {
  String? _activeColorTarget;

  Future<void> _importCustomFont(BuildContext context) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['ttf', 'otf'], dialogTitle: 'Select Custom Font');
    if (res != null && res.files.single.path != null) {
      final name = await FontLoaderService.loadCustomFont(res.files.single.path!);
      if (name != null) {
        ref.read(projectProvider.notifier).updateTextOverlay(widget.item.copyWith(fontFilePath: res.files.single.path!, fontFamily: name));
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loaded font: "$name"')));
      }
    }
  }

  void _snapToCurrentImage() {
    final images = ref.read(projectProvider).images;
    if (images.isEmpty) return;
    final idx = TimingEngine.findActiveImageIndex(images, ref.read(playheadPositionProvider));
    final t = idx >= 0 ? images[idx] : images.first;
    ref.read(projectProvider.notifier).trimTextOverlay(widget.item.id, startMs: t.startMs, durationMs: t.durationMs);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⏱ Snapped text duration to "${t.displayName}"!')));
  }

  Widget _buildColorButton(String target, String label, Color color) {
    final open = _activeColorTarget == target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _activeColorTarget = open ? null : target),
              child: Container(
                width: 58, height: 20,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4), border: Border.all(color: open ? Colors.amber : Colors.white38)),
                alignment: Alignment.center,
                child: Text(open ? 'Editing' : 'Pick', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white)),
              ),
            ),
          ],
        ),
        if (open)
          InlineColorPicker(
            title: label, currentColor: color,
            onColorChanged: (c) {
              final n = ref.read(projectProvider.notifier);
              if (target == 'text') n.updateTextOverlay(widget.item.copyWith(textColor: c), recordUndo: false);
              if (target == 'shadow') n.updateTextOverlay(widget.item.copyWith(shadowColor: c), recordUndo: false);
              if (target == 'outline') n.updateTextOverlay(widget.item.copyWith(outlineColor: c), recordUndo: false);
            },
          ),
      ],
    );
  }

  Widget _buildSliderRow(String label, double val, double min, double max, String display, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
        Expanded(child: Slider(value: val.clamp(min, max), min: min, max: max, activeColor: Colors.amber, onChanged: onChanged)),
        Text(display, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final notifier = ref.read(projectProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            const Icon(Icons.title, color: Colors.amber, size: 16),
            const SizedBox(width: 6),
            const Text('Text Inspector', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
              tooltip: 'Delete text overlay',
              onPressed: () { notifier.deleteTextOverlay(item.id); ref.read(selectedTextOverlayIdProvider.notifier).state = null; },
            ),
          ],
        ),
        TextField(
          controller: TextEditingController(text: item.text)..selection = TextSelection.collapsed(offset: item.text.length),
          style: const TextStyle(fontSize: 12, color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Text Content', labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
            filled: true, fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.surfaceBorder)),
          ),
          onChanged: (val) => notifier.updateTextOverlay(item.copyWith(text: val)),
        ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4), side: const BorderSide(color: Colors.amber)),
          icon: const Icon(Icons.timer, size: 12, color: Colors.amber),
          label: const Text('Match Active Image Duration', style: TextStyle(fontSize: 10, color: Colors.amber)),
          onPressed: _snapToCurrentImage,
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: FontLoaderService.presetFontFamilies.contains(item.fontFamily) || FontLoaderService.isFontLoaded(item.fontFamily) ? item.fontFamily : 'Roboto',
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(labelText: 'Font', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                items: [
                  ...FontLoaderService.presetFontFamilies.map((f) => DropdownMenuItem(value: f, child: Text(f, style: TextStyle(fontFamily: f, fontSize: 11)))),
                  if (item.fontFilePath != null) DropdownMenuItem(value: item.fontFamily, child: Text('${item.fontFamily} (Custom)', style: const TextStyle(fontSize: 11, color: Colors.amber))),
                ],
                onChanged: (val) { if (val != null) notifier.updateTextOverlay(item.copyWith(fontFamily: val)); },
              ),
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), side: const BorderSide(color: Colors.amber)),
              icon: const Icon(Icons.file_upload, size: 12, color: Colors.amber),
              label: const Text('Import Font', style: TextStyle(fontSize: 10, color: Colors.amber)),
              onPressed: () => _importCustomFont(context),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildColorButton('text', 'Text Color', item.textColor),
        const SizedBox(height: 4),
        _buildSliderRow('Size', item.fontSize, 14.0, 100.0, '${item.fontSize.round()}px', (v) => notifier.updateTextOverlay(item.copyWith(fontSize: v), recordUndo: false)),
        _buildSliderRow('Scale', item.scale, 0.4, 2.5, '${(item.scale * 100).round()}%', (v) => notifier.updateTextOverlay(item.copyWith(scale: v), recordUndo: false)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero, title: const Text('Drop Shadow', style: TextStyle(fontSize: 11, color: Colors.white)),
          value: item.hasShadow, activeTrackColor: Colors.amber, onChanged: (v) => notifier.updateTextOverlay(item.copyWith(hasShadow: v)),
        ),
        if (item.hasShadow) ...[
          _buildColorButton('shadow', 'Shadow Color', item.shadowColor),
          _buildSliderRow('Blur', item.shadowBlur, 0.0, 20.0, '${item.shadowBlur.round()}px', (v) => notifier.updateTextOverlay(item.copyWith(shadowBlur: v), recordUndo: false)),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero, title: const Text('Outline Stroke', style: TextStyle(fontSize: 11, color: Colors.white)),
          value: item.hasOutline, activeTrackColor: Colors.amber, onChanged: (v) => notifier.updateTextOverlay(item.copyWith(hasOutline: v)),
        ),
        if (item.hasOutline) _buildColorButton('outline', 'Outline Color', item.outlineColor),
        const SizedBox(height: 4),
        DropdownButtonFormField<TextAnimationType>(
          initialValue: item.animationType, dropdownColor: AppColors.surface,
          decoration: const InputDecoration(labelText: 'Animation Effect', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
          items: TextAnimationType.values.map((a) => DropdownMenuItem(value: a, child: Text(a.name, style: const TextStyle(fontSize: 11)))).toList(),
          onChanged: (val) { if (val != null) notifier.updateTextOverlay(item.copyWith(animationType: val)); },
        ),
        const SizedBox(height: 4),
        _buildSliderRow('Duration In', item.animationDurationMs.toDouble(), 100, 2000, '${(item.animationDurationMs / 1000).toStringAsFixed(2)}s', (v) => notifier.updateTextOverlay(item.copyWith(animationDurationMs: v.round()), recordUndo: false)),
        _buildSliderRow('Duration Out', item.animationOutDurationMs.toDouble(), 100, 2000, '${(item.animationOutDurationMs / 1000).toStringAsFixed(2)}s', (v) => notifier.updateTextOverlay(item.copyWith(animationOutDurationMs: v.round()), recordUndo: false)),
      ],
    );
  }
}
