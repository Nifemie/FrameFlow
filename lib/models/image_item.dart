import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import 'asset_animation.dart';
import 'asset_transform.dart';

enum ImageFitMode { fit, fill, blurredBackground, center }

@immutable
class ImageItem {
  final String id;
  final String filePath;
  final String displayName;
  final int orderIndex;
  final String? userStartTimestampInput;
  final String? userEndTimestampInput;
  final int startMs;
  final int endMs;
  final int durationMs;
  final ImageFitMode fitMode;
  final String? validationError;
  final int? backgroundColorValue;
  final String trackId;
  final AssetTransform transform;
  final List<AssetAnimation> animations;
  final int? mediaWidth;
  final int? mediaHeight;
  final int? sourceDurationMs;
  final int sourceStartOffsetMs;
  final bool isMuted;

  const ImageItem({
    required this.id,
    required this.filePath,
    required this.displayName,
    required this.orderIndex,
    this.userStartTimestampInput,
    this.userEndTimestampInput,
    this.startMs = 0,
    this.endMs = 0,
    this.durationMs = 0,
    this.fitMode = ImageFitMode.fit,
    this.validationError,
    this.backgroundColorValue,
    this.trackId = 'track_v1',
    this.transform = AssetTransform.identity,
    this.animations = const [],
    this.mediaWidth,
    this.mediaHeight,
    this.sourceDurationMs,
    this.sourceStartOffsetMs = 0,
    this.isMuted = false,
  });

  bool get isColorBackground => backgroundColorValue != null;
  Color? get backgroundColor => backgroundColorValue != null ? Color(backgroundColorValue!) : null;
  bool get isVideo => filePath.isNotEmpty && AppConstants.isVideoFile(filePath);
  bool get isImage => filePath.isNotEmpty && !isColorBackground && !isVideo;

  ImageItem copyWith({
    String? id,
    String? filePath,
    String? displayName,
    int? orderIndex,
    String? userStartTimestampInput,
    String? userEndTimestampInput,
    int? startMs,
    int? endMs,
    int? durationMs,
    ImageFitMode? fitMode,
    String? validationError,
    bool clearValidationError = false,
    bool clearStartTimestamp = false,
    int? backgroundColorValue,
    String? trackId,
    AssetTransform? transform,
    List<AssetAnimation>? animations,
    int? mediaWidth,
    int? mediaHeight,
    int? sourceDurationMs,
    int? sourceStartOffsetMs,
    bool? isMuted,
  }) {
    return ImageItem(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      displayName: displayName ?? this.displayName,
      orderIndex: orderIndex ?? this.orderIndex,
      userStartTimestampInput: clearStartTimestamp ? null : (userStartTimestampInput ?? this.userStartTimestampInput),
      userEndTimestampInput: userEndTimestampInput ?? this.userEndTimestampInput,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      durationMs: durationMs ?? this.durationMs,
      fitMode: fitMode ?? this.fitMode,
      validationError: clearValidationError ? null : (validationError ?? this.validationError),
      backgroundColorValue: backgroundColorValue ?? this.backgroundColorValue,
      trackId: trackId ?? this.trackId,
      transform: transform ?? this.transform,
      animations: animations ?? this.animations,
      mediaWidth: mediaWidth ?? this.mediaWidth,
      mediaHeight: mediaHeight ?? this.mediaHeight,
      sourceDurationMs: sourceDurationMs ?? this.sourceDurationMs,
      sourceStartOffsetMs: sourceStartOffsetMs ?? this.sourceStartOffsetMs,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          filePath == other.filePath &&
          displayName == other.displayName &&
          orderIndex == other.orderIndex &&
          userStartTimestampInput == other.userStartTimestampInput &&
          userEndTimestampInput == other.userEndTimestampInput &&
          startMs == other.startMs &&
          endMs == other.endMs &&
          durationMs == other.durationMs &&
          fitMode == other.fitMode &&
          validationError == other.validationError &&
          backgroundColorValue == other.backgroundColorValue &&
          trackId == other.trackId &&
          transform == other.transform &&
          sourceStartOffsetMs == other.sourceStartOffsetMs &&
          listEquals(animations, other.animations);

  @override
  int get hashCode => Object.hash(
        id, filePath, displayName, orderIndex, userStartTimestampInput,
        userEndTimestampInput, startMs, endMs, durationMs, fitMode,
        validationError, backgroundColorValue, trackId, transform, sourceStartOffsetMs, Object.hashAll(animations),
      );
}
