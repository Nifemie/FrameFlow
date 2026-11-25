import 'package:flutter/foundation.dart';
import 'keyframe_item.dart';

enum AnimationCategory {
  entrance('Entrance'),
  exit('Exit'),
  movement('Movement'),
  zoom('Zoom'),
  rotation('Rotation'),
  opacity('Opacity'),
  continuous('Continuous'),
  attention('Attention Grabbing');

  final String label;
  const AnimationCategory(this.label);
}

@immutable
class AssetAnimation {
  final String id;
  final String presetId;
  final AnimationCategory category;
  final int startOffsetMs;
  final int durationMs;
  final KeyframeEasing easing;
  final double intensity;
  final bool isLocked;
  final String direction; // 'left', 'right', 'top', 'bottom', 'center'
  final bool isExit; // false = In (entrance), true = Out (exit)
  final Map<String, List<KeyframeItem>> customKeyframes;

  const AssetAnimation({
    required this.id,
    required this.presetId,
    required this.category,
    this.startOffsetMs = 0,
    this.durationMs = 600,
    this.easing = KeyframeEasing.easeInOut,
    this.intensity = 1.0,
    this.isLocked = false,
    this.direction = 'center',
    this.isExit = false,
    this.customKeyframes = const {},
  });

  AssetAnimation copyWith({
    String? id,
    String? presetId,
    AnimationCategory? category,
    int? startOffsetMs,
    int? durationMs,
    KeyframeEasing? easing,
    double? intensity,
    bool? isLocked,
    String? direction,
    bool? isExit,
    Map<String, List<KeyframeItem>>? customKeyframes,
  }) {
    return AssetAnimation(
      id: id ?? this.id,
      presetId: presetId ?? this.presetId,
      category: category ?? this.category,
      startOffsetMs: startOffsetMs ?? this.startOffsetMs,
      durationMs: durationMs ?? this.durationMs,
      easing: easing ?? this.easing,
      intensity: intensity ?? this.intensity,
      isLocked: isLocked ?? this.isLocked,
      direction: direction ?? this.direction,
      isExit: isExit ?? this.isExit,
      customKeyframes: customKeyframes ?? this.customKeyframes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'presetId': presetId,
        'category': category.name,
        'startOffsetMs': startOffsetMs,
        'durationMs': durationMs,
        'easing': easing.name,
        'intensity': intensity,
        'isLocked': isLocked,
        'direction': direction,
        'isExit': isExit,
        'customKeyframes': customKeyframes.map(
          (k, v) => MapEntry(k, v.map((item) => item.toJson()).toList()),
        ),
      };

  factory AssetAnimation.fromJson(Map<String, dynamic> json) {
    final cat = AnimationCategory.values.firstWhere(
      (c) => c.name == json['category'],
      orElse: () => AnimationCategory.entrance,
    );
    final eas = KeyframeEasing.values.firstWhere(
      (e) => e.name == json['easing'],
      orElse: () => KeyframeEasing.easeInOut,
    );
    final rawKeyframes = json['customKeyframes'] as Map<String, dynamic>? ?? {};
    final customKeyframes = rawKeyframes.map(
      (k, v) => MapEntry(
        k,
        (v as List<dynamic>).map((item) => KeyframeItem.fromJson(item as Map<String, dynamic>)).toList(),
      ),
    );

    final preset = json['presetId'] as String;
    final inferredExit = json['isExit'] as bool? ?? (cat == AnimationCategory.exit || preset.toLowerCase().contains('out'));
    String inferredDir = json['direction'] as String? ?? 'center';
    if (inferredDir == 'center') {
      if (preset.toLowerCase().contains('left')) inferredDir = 'left';
      if (preset.toLowerCase().contains('right')) inferredDir = 'right';
      if (preset.toLowerCase().contains('top')) inferredDir = 'top';
      if (preset.toLowerCase().contains('bottom')) inferredDir = 'bottom';
    }

    return AssetAnimation(
      id: json['id'] as String,
      presetId: preset,
      category: cat,
      startOffsetMs: json['startOffsetMs'] as int? ?? 0,
      durationMs: json['durationMs'] as int? ?? 600,
      easing: eas,
      intensity: (json['intensity'] as num?)?.toDouble() ?? 1.0,
      isLocked: json['isLocked'] as bool? ?? false,
      direction: inferredDir,
      isExit: inferredExit,
      customKeyframes: customKeyframes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetAnimation &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          presetId == other.presetId &&
          category == other.category &&
          startOffsetMs == other.startOffsetMs &&
          durationMs == other.durationMs &&
          easing == other.easing &&
          intensity == other.intensity &&
          isLocked == other.isLocked &&
          direction == other.direction &&
          isExit == other.isExit;

  @override
  int get hashCode => Object.hash(
        id, presetId, category, startOffsetMs, durationMs, easing, intensity, isLocked, direction, isExit,
      );
}
