import 'package:flutter/material.dart';
import 'asset_animation.dart';
import 'keyframe_item.dart';

@immutable
class AnimationPreset {
  final String id;
  final String name;
  final AnimationCategory category;
  final String description;
  final IconData icon;
  final int defaultDurationMs;
  final KeyframeEasing defaultEasing;

  const AnimationPreset({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.icon,
    this.defaultDurationMs = 600,
    this.defaultEasing = KeyframeEasing.easeInOut,
  });

  AssetAnimation toAssetAnimation({
    String? id,
    int startOffsetMs = 0,
    int? durationMs,
    KeyframeEasing? easing,
    double intensity = 1.0,
    bool isLocked = false,
    String? direction,
    bool? isExit,
  }) {
    final exit = isExit ?? (category == AnimationCategory.exit || this.id.toLowerCase().contains('out'));
    String dir = direction ?? 'center';
    if (direction == null) {
      if (this.id.toLowerCase().contains('left')) dir = 'left';
      if (this.id.toLowerCase().contains('right')) dir = 'right';
      if (this.id.toLowerCase().contains('top')) dir = 'top';
      if (this.id.toLowerCase().contains('bottom')) dir = 'bottom';
    }

    return AssetAnimation(
      id: id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      presetId: this.id,
      category: category,
      startOffsetMs: startOffsetMs,
      durationMs: durationMs ?? defaultDurationMs,
      easing: easing ?? defaultEasing,
      intensity: intensity,
      isLocked: isLocked,
      direction: dir,
      isExit: exit,
    );
  }
}
