import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/animation_preset.dart';
import '../../../models/asset_animation.dart';
import '../../../models/asset_transform.dart';
import '../../../models/image_item.dart';
import '../../../providers/project_provider.dart';
import '../../../services/animation_library.dart';

class AssetAnimationEditor extends ConsumerWidget {
  final ImageItem item;
  const AssetAnimationEditor({super.key, required this.item});

  void _updateT(WidgetRef ref, AssetTransform newT) => ref.read(projectProvider.notifier).updateImageTransform(item.id, newT, recordUndo: true);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = item.transform;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('TRANSFORM & MOTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5)),
            TextButton(onPressed: () => _updateT(ref, AssetTransform.identity), child: const Text('Reset', style: TextStyle(fontSize: 10, color: AppColors.accentBlue))),
          ],
        ),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(child: _buildNumField('Pos X', (t.positionX * 100).round(), (v) => _updateT(ref, t.copyWith(positionX: v / 100.0)))),
          const SizedBox(width: 8),
          Expanded(child: _buildNumField('Pos Y', (t.positionY * 100).round(), (v) => _updateT(ref, t.copyWith(positionY: v / 100.0)))),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _buildNumField('Scale %', (t.scaleX * 100).round(), (v) => _updateT(ref, t.copyWith(scaleX: v / 100.0, scaleY: v / 100.0)))),
          const SizedBox(width: 8),
          Expanded(child: _buildNumField('Rot °', (t.rotation * 180 / pi).round(), (v) => _updateT(ref, t.copyWith(rotation: v * pi / 180)))),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Text('Opacity', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
          Expanded(child: Slider(value: t.opacity, min: 0.0, max: 1.0, activeColor: AppColors.accentBlue, onChanged: (v) => _updateT(ref, t.copyWith(opacity: v)))),
          Text('${(t.opacity * 100).round()}%', style: const TextStyle(fontSize: 10, color: Colors.white)),
        ]),
        const SizedBox(height: 8),
        const Divider(height: 1, color: AppColors.surfaceBorder),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ANIMATIONS (${item.animations.length})', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5)),
            PopupMenuButton<AnimationPreset>(
              tooltip: 'Add Animation', icon: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.accentBlue),
              padding: EdgeInsets.zero, color: AppColors.cardSurface,
              onSelected: (p) => ref.read(projectProvider.notifier).addImageAnimation(item.id, p.toAssetAnimation()),
              itemBuilder: (_) => AnimationLibrary.presets.map((p) => PopupMenuItem(value: p, child: Row(children: [Icon(p.icon, size: 14, color: AppColors.accentBlue), const SizedBox(width: 8), Text(p.name, style: const TextStyle(fontSize: 11, color: Colors.white))]))).toList(),
            ),
          ],
        ),
        if (item.animations.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No animation applied. Use + or Randomise.', style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontStyle: FontStyle.italic)))
        else
          ...item.animations.map((a) => _buildAnimationRow(ref, a)),
      ],
    );
  }

  Widget _buildAnimationRow(WidgetRef ref, AssetAnimation a) {
    final preset = AnimationLibrary.findById(a.presetId);
    final name = preset?.name ?? a.presetId;
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.surfaceBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(preset?.icon ?? Icons.movie_filter, size: 14, color: AppColors.accentBlue),
            const SizedBox(width: 6),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white))),
            IconButton(iconSize: 14, padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: Icon(a.isLocked ? Icons.lock : Icons.lock_open, color: a.isLocked ? AppColors.warningYellow : AppColors.textMuted), onPressed: () => ref.read(projectProvider.notifier).updateImageAnimation(item.id, a.copyWith(isLocked: !a.isLocked))),
            const SizedBox(width: 6),
            IconButton(iconSize: 14, padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.close, color: AppColors.errorRed), onPressed: () => ref.read(projectProvider.notifier).removeImageAnimation(item.id, a.id)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            _phaseChip(ref, a, isExit: false, label: 'IN'),
            const SizedBox(width: 4),
            _phaseChip(ref, a, isExit: true, label: 'OUT'),
            const Spacer(),
            _dirIcon(ref, a, 'left', Icons.arrow_back),
            _dirIcon(ref, a, 'right', Icons.arrow_forward),
            _dirIcon(ref, a, 'top', Icons.arrow_upward),
            _dirIcon(ref, a, 'bottom', Icons.arrow_downward),
            _dirIcon(ref, a, 'center', Icons.filter_center_focus),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text('${a.durationMs}ms', style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
            Expanded(child: Slider(value: a.durationMs.toDouble().clamp(100.0, 3000.0), min: 100.0, max: 3000.0, divisions: 29, activeColor: AppColors.accentBlue, onChanged: (v) => ref.read(projectProvider.notifier).updateImageAnimation(item.id, a.copyWith(durationMs: v.round())))),
          ]),
        ],
      ),
    );
  }

  Widget _phaseChip(WidgetRef ref, AssetAnimation a, {required bool isExit, required String label}) {
    final active = a.isExit == isExit;
    return InkWell(
      onTap: () => ref.read(projectProvider.notifier).updateImageAnimation(item.id, a.copyWith(isExit: isExit, category: isExit ? AnimationCategory.exit : AnimationCategory.entrance)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: active ? AppColors.accentBlue : AppColors.surfaceBorder, borderRadius: BorderRadius.circular(3)),
        child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: active ? Colors.white : AppColors.textMuted)),
      ),
    );
  }

  Widget _dirIcon(WidgetRef ref, AssetAnimation a, String dir, IconData icon) {
    final active = a.direction == dir;
    return InkWell(
      onTap: () => ref.read(projectProvider.notifier).updateImageAnimation(item.id, a.copyWith(direction: dir)),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Icon(icon, size: 14, color: active ? AppColors.accentBlue : AppColors.textMuted)),
    );
  }

  Widget _buildNumField(String label, int value, ValueChanged<int> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.surfaceBorder)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
        Text('$value', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
      ]),
    );
  }
}
