import 'dart:math';
import '../models/asset_animation.dart';
import '../models/asset_transform.dart';

class AnimationTransformEvaluator {
  static AssetTransform evaluate({
    required AssetTransform baseTransform,
    required List<AssetAnimation> animations,
    required int clipElapsedMs,
    required int clipDurationMs,
  }) {
    if (animations.isEmpty) return baseTransform;
    final dur = max(1, clipDurationMs);
    final elapsed = clipElapsedMs.clamp(0, dur);
    final remaining = dur - elapsed;

    double posX = baseTransform.positionX;
    double posY = baseTransform.positionY;
    double scaleX = baseTransform.scaleX;
    double scaleY = baseTransform.scaleY;
    double rotation = baseTransform.rotation;
    double opacity = baseTransform.opacity;

    for (final anim in animations) {
      final aDur = max(50, anim.durationMs);
      final pIn = (elapsed / aDur).clamp(0.0, 1.0);
      final pOut = (remaining / aDur).clamp(0.0, 1.0);
      final t = (elapsed / dur).clamp(0.0, 1.0);
      final easeIn = anim.easing.curve.transform(pIn);
      final easeOut = anim.easing.curve.transform(pOut);
      final isOut = anim.isExit;

      // Directional override
      if (anim.direction != 'center') {
        if (!isOut && elapsed < aDur) {
          if (anim.direction == 'left') posX += (-1.0 + easeIn) * 0.8 * anim.intensity;
          if (anim.direction == 'right') posX += (1.0 - easeIn) * 0.8 * anim.intensity;
          if (anim.direction == 'top') posY += (-1.0 + easeIn) * 0.8 * anim.intensity;
          if (anim.direction == 'bottom') posY += (1.0 - easeIn) * 0.8 * anim.intensity;
          opacity *= easeIn;
        } else if (isOut && remaining < aDur) {
          if (anim.direction == 'left') posX += (1.0 - easeOut) * -0.8 * anim.intensity;
          if (anim.direction == 'right') posX += (1.0 - easeOut) * 0.8 * anim.intensity;
          if (anim.direction == 'top') posY += (1.0 - easeOut) * -0.8 * anim.intensity;
          if (anim.direction == 'bottom') posY += (1.0 - easeOut) * 0.8 * anim.intensity;
          opacity *= easeOut;
        }
        continue;
      }

      switch (anim.presetId) {
        case 'zoomIn':
        case 'zoomOutExit':
          if (!isOut && elapsed < aDur) { scaleX *= easeIn; scaleY *= easeIn; opacity *= easeIn; }
          if (isOut && remaining < aDur) { scaleX *= easeOut; scaleY *= easeOut; opacity *= easeOut; }
          break;
        case 'zoomOutEntrance':
          if (elapsed < aDur) { final s = 1.5 - 0.5 * easeIn; scaleX *= s; scaleY *= s; opacity *= easeIn; }
          break;
        case 'fadeIn':
        case 'fadeOut':
          if (!isOut && elapsed < aDur) opacity *= easeIn;
          if (isOut && remaining < aDur) opacity *= easeOut;
          break;
        case 'slideInLeft':
        case 'slideOutLeft':
          if (!isOut && elapsed < aDur) { posX += (-1.0 + easeIn) * 0.8 * anim.intensity; opacity *= easeIn; }
          if (isOut && remaining < aDur) { posX += (-1.0 + easeOut) * -0.8 * anim.intensity; opacity *= easeOut; }
          break;
        case 'slideInRight':
        case 'slideOutRight':
          if (!isOut && elapsed < aDur) { posX += (1.0 - easeIn) * 0.8 * anim.intensity; opacity *= easeIn; }
          if (isOut && remaining < aDur) { posX += (1.0 - easeOut) * 0.8 * anim.intensity; opacity *= easeOut; }
          break;
        case 'slideInTop':
        case 'slideOutTop':
          if (!isOut && elapsed < aDur) { posY += (-1.0 + easeIn) * 0.8 * anim.intensity; opacity *= easeIn; }
          if (isOut && remaining < aDur) { posY += (-1.0 + easeOut) * -0.8 * anim.intensity; opacity *= easeOut; }
          break;
        case 'slideInBottom':
        case 'slideOutBottom':
          if (!isOut && elapsed < aDur) { posY += (1.0 - easeIn) * 0.8 * anim.intensity; opacity *= easeIn; }
          if (isOut && remaining < aDur) { posY += (1.0 - easeOut) * 0.8 * anim.intensity; opacity *= easeOut; }
          break;
        case 'popIn':
          if (elapsed < aDur) { final s = (0.2 + 0.8 * easeIn); scaleX *= s; scaleY *= s; opacity *= easeIn; }
          break;
        case 'bounceIn':
          if (elapsed < aDur) { scaleX *= easeIn; scaleY *= easeIn; opacity *= easeIn; }
          break;
        case 'rotateIn':
          if (elapsed < aDur) { rotation += (1.0 - easeIn) * -0.5 * anim.intensity; scaleX *= (0.5 + 0.5 * easeIn); scaleY *= (0.5 + 0.5 * easeIn); opacity *= easeIn; }
          break;
        case 'shrinkOut':
          if (remaining < aDur) { scaleX *= easeOut; scaleY *= easeOut; opacity *= easeOut; }
          break;
        case 'moveLeft': posX -= 0.15 * t * anim.intensity; break;
        case 'moveRight': posX += 0.15 * t * anim.intensity; break;
        case 'moveUp': posY -= 0.15 * t * anim.intensity; break;
        case 'moveDown': posY += 0.15 * t * anim.intensity; break;
        case 'drift':
          posX += (-0.05 + 0.10 * t) * anim.intensity; posY += (0.04 - 0.08 * t) * anim.intensity;
          scaleX *= (1.04 + 0.04 * t); scaleY *= (1.04 + 0.04 * t);
          break;
        case 'shake':
          posX += sin(t * 30 * pi) * 0.02 * anim.intensity; posY += cos(t * 26 * pi) * 0.015 * anim.intensity;
          break;
        case 'wobble': rotation += sin(t * 8 * pi) * 0.05 * anim.intensity; break;
        case 'slowZoomIn':
          final sIn = 1.0 + 0.15 * t * anim.intensity; scaleX *= sIn; scaleY *= sIn;
          break;
        case 'slowZoomOut':
          final sOut = 1.15 - 0.15 * t * anim.intensity; scaleX *= sOut; scaleY *= sOut;
          break;
        case 'pulseZoom':
          final sPulse = 1.0 + 0.08 * sin(t * 4 * pi) * anim.intensity; scaleX *= sPulse; scaleY *= sPulse;
          break;
        case 'rotateClockwise': rotation += (2 * pi * t) * anim.intensity; break;
        case 'rotateCounterClockwise': rotation -= (2 * pi * t) * anim.intensity; break;
        case 'continuousRotation':
          final rotP = (elapsed % aDur) / aDur; rotation += (2 * pi * rotP) * anim.intensity;
          break;
        case 'rocking': rotation += sin(t * 6 * pi) * 0.1 * anim.intensity; break;
      }
    }

    return baseTransform.copyWith(
      positionX: posX, positionY: posY, scaleX: scaleX, scaleY: scaleY, rotation: rotation,
      opacity: opacity.clamp(0.0, 1.0),
    );
  }
}
