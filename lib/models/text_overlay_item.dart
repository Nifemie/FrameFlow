import 'package:flutter/material.dart';

enum TextAnimationType {
  none, fadeIn, fadeOut, fadeBoth, slideUp, slideDown, slideLeft, slideRight, zoomIn, bounce, typewriter, rotateIn, popScale
}

@immutable
class TextOverlayItem {
  final String id;
  final String text;
  final int startMs;
  final int durationMs;
  final String? fontFilePath;
  final String fontFamily;
  final double fontSize;
  final Color textColor;
  final bool hasShadow;
  final Color shadowColor;
  final double shadowBlur;
  final double shadowOffsetX;
  final double shadowOffsetY;
  final bool hasOutline;
  final Color outlineColor;
  final double outlineWidth;
  final double positionX; // -1.0 to 1.0
  final double positionY; // -1.0 to 1.0
  final double scale;
  final double opacity;
  final TextAnimationType animationType;
  final int animationDurationMs; // In duration
  final int animationOutDurationMs; // Out duration

  const TextOverlayItem({
    required this.id,
    required this.text,
    required this.startMs,
    this.durationMs = 3000,
    this.fontFilePath,
    this.fontFamily = 'Roboto',
    this.fontSize = 36.0,
    this.textColor = Colors.white,
    this.hasShadow = true,
    this.shadowColor = Colors.black87,
    this.shadowBlur = 6.0,
    this.shadowOffsetX = 2.0,
    this.shadowOffsetY = 2.0,
    this.hasOutline = false,
    this.outlineColor = Colors.black,
    this.outlineWidth = 2.0,
    this.positionX = 0.0,
    this.positionY = 0.7,
    this.scale = 1.0,
    this.opacity = 1.0,
    this.animationType = TextAnimationType.fadeIn,
    this.animationDurationMs = 350,
    this.animationOutDurationMs = 350,
  });

  int get endMs => startMs + durationMs;

  TextOverlayItem copyWith({
    String? id,
    String? text,
    int? startMs,
    int? durationMs,
    String? fontFilePath,
    bool clearFontFile = false,
    String? fontFamily,
    double? fontSize,
    Color? textColor,
    bool? hasShadow,
    Color? shadowColor,
    double? shadowBlur,
    double? shadowOffsetX,
    double? shadowOffsetY,
    bool? hasOutline,
    Color? outlineColor,
    double? outlineWidth,
    double? positionX,
    double? positionY,
    double? scale,
    double? opacity,
    TextAnimationType? animationType,
    int? animationDurationMs,
    int? animationOutDurationMs,
  }) {
    return TextOverlayItem(
      id: id ?? this.id,
      text: text ?? this.text,
      startMs: startMs ?? this.startMs,
      durationMs: durationMs ?? this.durationMs,
      fontFilePath: clearFontFile ? null : (fontFilePath ?? this.fontFilePath),
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      hasShadow: hasShadow ?? this.hasShadow,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      shadowOffsetX: shadowOffsetX ?? this.shadowOffsetX,
      shadowOffsetY: shadowOffsetY ?? this.shadowOffsetY,
      hasOutline: hasOutline ?? this.hasOutline,
      outlineColor: outlineColor ?? this.outlineColor,
      outlineWidth: outlineWidth ?? this.outlineWidth,
      positionX: positionX ?? this.positionX,
      positionY: positionY ?? this.positionY,
      scale: scale ?? this.scale,
      opacity: opacity ?? this.opacity,
      animationType: animationType ?? this.animationType,
      animationDurationMs: animationDurationMs ?? this.animationDurationMs,
      animationOutDurationMs: animationOutDurationMs ?? this.animationOutDurationMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'startMs': startMs,
    'durationMs': durationMs,
    'fontFilePath': fontFilePath,
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'textColor': textColor.toARGB32(),
    'hasShadow': hasShadow,
    'shadowColor': shadowColor.toARGB32(),
    'shadowBlur': shadowBlur,
    'shadowOffsetX': shadowOffsetX,
    'shadowOffsetY': shadowOffsetY,
    'hasOutline': hasOutline,
    'outlineColor': outlineColor.toARGB32(),
    'outlineWidth': outlineWidth,
    'positionX': positionX,
    'positionY': positionY,
    'scale': scale,
    'opacity': opacity,
    'animationType': animationType.name,
    'animationDurationMs': animationDurationMs,
    'animationOutDurationMs': animationOutDurationMs,
  };

  factory TextOverlayItem.fromJson(Map<String, dynamic> json) => TextOverlayItem(
    id: json['id'] as String,
    text: json['text'] as String,
    startMs: json['startMs'] as int,
    durationMs: json['durationMs'] as int? ?? 3000,
    fontFilePath: json['fontFilePath'] as String?,
    fontFamily: json['fontFamily'] as String? ?? 'Roboto',
    fontSize: (json['fontSize'] as num?)?.toDouble() ?? 36.0,
    textColor: json['textColor'] != null ? Color(json['textColor'] as int) : Colors.white,
    hasShadow: json['hasShadow'] as bool? ?? true,
    shadowColor: json['shadowColor'] != null ? Color(json['shadowColor'] as int) : Colors.black87,
    shadowBlur: (json['shadowBlur'] as num?)?.toDouble() ?? 6.0,
    shadowOffsetX: (json['shadowOffsetX'] as num?)?.toDouble() ?? 2.0,
    shadowOffsetY: (json['shadowOffsetY'] as num?)?.toDouble() ?? 2.0,
    hasOutline: json['hasOutline'] as bool? ?? false,
    outlineColor: json['outlineColor'] != null ? Color(json['outlineColor'] as int) : Colors.black,
    outlineWidth: (json['outlineWidth'] as num?)?.toDouble() ?? 2.0,
    positionX: (json['positionX'] as num?)?.toDouble() ?? 0.0,
    positionY: (json['positionY'] as num?)?.toDouble() ?? 0.7,
    scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
    opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
    animationType: TextAnimationType.values.firstWhere((e) => e.name == json['animationType'], orElse: () => TextAnimationType.fadeIn),
    animationDurationMs: json['animationDurationMs'] as int? ?? 350,
    animationOutDurationMs: json['animationOutDurationMs'] as int? ?? 350,
  );
}
