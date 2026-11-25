import 'package:flutter/material.dart';
import '../models/animation_preset.dart';
import '../models/asset_animation.dart';
import '../models/keyframe_item.dart';

class AnimationLibrary {
  static const List<AnimationPreset> presets = [
    // Entrance
    AnimationPreset(id: 'zoomIn', name: 'Zoom In', category: AnimationCategory.entrance, description: 'Scales up smoothly from zero', icon: Icons.zoom_in, defaultDurationMs: 600),
    AnimationPreset(id: 'zoomOutEntrance', name: 'Zoom Out (Entrance)', category: AnimationCategory.entrance, description: 'Scales down from oversized into place', icon: Icons.zoom_out_map, defaultDurationMs: 600),
    AnimationPreset(id: 'fadeIn', name: 'Fade In', category: AnimationCategory.entrance, description: 'Smoothly transitions opacity from 0% to 100%', icon: Icons.opacity, defaultDurationMs: 500),
    AnimationPreset(id: 'slideInLeft', name: 'Slide In Left', category: AnimationCategory.entrance, description: 'Glides into frame from the left edge', icon: Icons.arrow_forward, defaultDurationMs: 600),
    AnimationPreset(id: 'slideInRight', name: 'Slide In Right', category: AnimationCategory.entrance, description: 'Glides into frame from the right edge', icon: Icons.arrow_back, defaultDurationMs: 600),
    AnimationPreset(id: 'slideInTop', name: 'Slide In Top', category: AnimationCategory.entrance, description: 'Enters downward from the top edge', icon: Icons.arrow_downward, defaultDurationMs: 600),
    AnimationPreset(id: 'slideInBottom', name: 'Slide In Bottom', category: AnimationCategory.entrance, description: 'Enters upward from the bottom edge', icon: Icons.arrow_upward, defaultDurationMs: 600),
    AnimationPreset(id: 'popIn', name: 'Pop In', category: AnimationCategory.entrance, description: 'Energetic scale-pop with overshoot', icon: Icons.flare, defaultDurationMs: 500, defaultEasing: KeyframeEasing.easeOutBack),
    AnimationPreset(id: 'bounceIn', name: 'Bounce In', category: AnimationCategory.entrance, description: 'Playful spring elastic entrance', icon: Icons.sports_volleyball, defaultDurationMs: 700, defaultEasing: KeyframeEasing.bounceOut),
    AnimationPreset(id: 'rotateIn', name: 'Rotate In', category: AnimationCategory.entrance, description: 'Rotates into frame while fading and scaling', icon: Icons.rotate_right, defaultDurationMs: 650),

    // Exit
    AnimationPreset(id: 'zoomOutExit', name: 'Zoom Out', category: AnimationCategory.exit, description: 'Scales down into zero towards clip end', icon: Icons.zoom_out, defaultDurationMs: 600),
    AnimationPreset(id: 'fadeOut', name: 'Fade Out', category: AnimationCategory.exit, description: 'Fades opacity out smoothly before transition', icon: Icons.blur_linear, defaultDurationMs: 500),
    AnimationPreset(id: 'slideOutLeft', name: 'Slide Out Left', category: AnimationCategory.exit, description: 'Glides out of frame to the left', icon: Icons.arrow_back, defaultDurationMs: 500),
    AnimationPreset(id: 'slideOutRight', name: 'Slide Out Right', category: AnimationCategory.exit, description: 'Glides out of frame to the right', icon: Icons.arrow_forward, defaultDurationMs: 500),
    AnimationPreset(id: 'slideOutTop', name: 'Slide Out Top', category: AnimationCategory.exit, description: 'Exits upward through top boundary', icon: Icons.arrow_upward, defaultDurationMs: 500),
    AnimationPreset(id: 'slideOutBottom', name: 'Slide Out Bottom', category: AnimationCategory.exit, description: 'Exits downward through bottom boundary', icon: Icons.arrow_downward, defaultDurationMs: 500),
    AnimationPreset(id: 'shrinkOut', name: 'Shrink Out', category: AnimationCategory.exit, description: 'Collapses to center point and disappears', icon: Icons.compress, defaultDurationMs: 500),

    // Movement & Drift
    AnimationPreset(id: 'moveLeft', name: 'Move Left', category: AnimationCategory.movement, description: 'Continuous smooth translation to the left', icon: Icons.keyboard_double_arrow_left, defaultDurationMs: 3000),
    AnimationPreset(id: 'moveRight', name: 'Move Right', category: AnimationCategory.movement, description: 'Continuous smooth translation to the right', icon: Icons.keyboard_double_arrow_right, defaultDurationMs: 3000),
    AnimationPreset(id: 'moveUp', name: 'Move Up', category: AnimationCategory.movement, description: 'Continuous upward pan across asset', icon: Icons.keyboard_double_arrow_up, defaultDurationMs: 3000),
    AnimationPreset(id: 'moveDown', name: 'Move Down', category: AnimationCategory.movement, description: 'Continuous downward pan across asset', icon: Icons.keyboard_double_arrow_down, defaultDurationMs: 3000),
    AnimationPreset(id: 'drift', name: 'Drift (Ken Burns)', category: AnimationCategory.movement, description: 'Cinematic diagonal float across frame', icon: Icons.air, defaultDurationMs: 4000),
    AnimationPreset(id: 'shake', name: 'Camera Shake', category: AnimationCategory.movement, description: 'Subtle rhythmic organic camera vibration', icon: Icons.vibration, defaultDurationMs: 1200),
    AnimationPreset(id: 'wobble', name: 'Wobble', category: AnimationCategory.movement, description: 'Gentle playful oscillation back and forth', icon: Icons.waves, defaultDurationMs: 1500),

    // Zoom (Ken Burns)
    AnimationPreset(id: 'slowZoomIn', name: 'Slow Zoom In', category: AnimationCategory.zoom, description: 'Gentle documentary-style zoom into focal point', icon: Icons.add_circle_outline, defaultDurationMs: 4000),
    AnimationPreset(id: 'slowZoomOut', name: 'Slow Zoom Out', category: AnimationCategory.zoom, description: 'Gentle reveal zoom pulling back slowly', icon: Icons.remove_circle_outline, defaultDurationMs: 4000),
    AnimationPreset(id: 'pulseZoom', name: 'Pulse Zoom', category: AnimationCategory.zoom, description: 'Heartbeat scale expansion and return', icon: Icons.favorite, defaultDurationMs: 1200),

    // Rotation
    AnimationPreset(id: 'rotateClockwise', name: 'Rotate Clockwise', category: AnimationCategory.rotation, description: 'Single smooth clockwise tilt or spin', icon: Icons.rotate_90_degrees_cw, defaultDurationMs: 1000),
    AnimationPreset(id: 'rotateCounterClockwise', name: 'Rotate CCW', category: AnimationCategory.rotation, description: 'Single counterclockwise tilt or spin', icon: Icons.rotate_90_degrees_ccw, defaultDurationMs: 1000),
    AnimationPreset(id: 'continuousRotation', name: 'Continuous Spin', category: AnimationCategory.rotation, description: 'Endless steady 360-degree rotation', icon: Icons.sync, defaultDurationMs: 5000),
    AnimationPreset(id: 'rocking', name: 'Rocking Motion', category: AnimationCategory.rotation, description: 'Back-and-forth pendulum sway', icon: Icons.swap_horiz, defaultDurationMs: 2000),
  ];

  static List<AnimationPreset> byCategory(AnimationCategory cat) =>
      presets.where((p) => p.category == cat).toList();

  static AnimationPreset? findById(String id) {
    try {
      return presets.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
