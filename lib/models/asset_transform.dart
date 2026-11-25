import 'package:flutter/foundation.dart';

@immutable
class AssetTransform {
  final double positionX; // Normalized offset from center (-1.0 to 1.0) or canvas px
  final double positionY;
  final double scaleX;
  final double scaleY;
  final double rotation; // Radians
  final double opacity; // 0.0 to 1.0
  final double anchorX; // 0.0 to 1.0 (default 0.5 center)
  final double anchorY;
  final bool maintainAspectRatio;

  const AssetTransform({
    this.positionX = 0.0,
    this.positionY = 0.0,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.rotation = 0.0,
    this.opacity = 1.0,
    this.anchorX = 0.5,
    this.anchorY = 0.5,
    this.maintainAspectRatio = true,
  });

  static const AssetTransform identity = AssetTransform();

  double get scale => scaleX; // Convenience getter for uniform scale

  AssetTransform copyWith({
    double? positionX,
    double? positionY,
    double? scaleX,
    double? scaleY,
    double? rotation,
    double? opacity,
    double? anchorX,
    double? anchorY,
    bool? maintainAspectRatio,
  }) {
    return AssetTransform(
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      anchorX: anchorX ?? this.anchorX,
      anchorY: anchorY ?? this.anchorY,
      maintainAspectRatio: maintainAspectRatio ?? this.maintainAspectRatio,
    );
  }

  Map<String, dynamic> toJson() => {
        'positionX': positionX,
        'positionY': positionY,
        'scaleX': scaleX,
        'scaleY': scaleY,
        'rotation': rotation,
        'opacity': opacity,
        'anchorX': anchorX,
        'anchorY': anchorY,
        'maintainAspectRatio': maintainAspectRatio,
      };

  factory AssetTransform.fromJson(Map<String, dynamic>? json) {
    if (json == null) return identity;
    return AssetTransform(
      positionX: (json['positionX'] as num?)?.toDouble() ?? 0.0,
      positionY: (json['positionY'] as num?)?.toDouble() ?? 0.0,
      scaleX: (json['scaleX'] as num?)?.toDouble() ?? 1.0,
      scaleY: (json['scaleY'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      anchorX: (json['anchorX'] as num?)?.toDouble() ?? 0.5,
      anchorY: (json['anchorY'] as num?)?.toDouble() ?? 0.5,
      maintainAspectRatio: json['maintainAspectRatio'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetTransform &&
          runtimeType == other.runtimeType &&
          positionX == other.positionX &&
          positionY == other.positionY &&
          scaleX == other.scaleX &&
          scaleY == other.scaleY &&
          rotation == other.rotation &&
          opacity == other.opacity &&
          anchorX == other.anchorX &&
          anchorY == other.anchorY &&
          maintainAspectRatio == other.maintainAspectRatio;

  @override
  int get hashCode => Object.hash(
        positionX, positionY, scaleX, scaleY, rotation, opacity, anchorX, anchorY, maintainAspectRatio,
      );
}
