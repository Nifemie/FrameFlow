import 'package:flutter/foundation.dart';

/// Supported image scaling and fit modes within the video frame.
enum ImageFitMode {
  /// Letterbox/pillarbox to show entire image without cropping
  fit,

  /// Zoom and fill the frame, cropping excess edges
  fill,

  /// Center the image and show a blurred version as background
  blurredBackground,

  /// Center original dimensions without stretching
  center,
}

/// Represents a single image clip in the project sequence.
@immutable
class ImageItem {
  final String id;
  final String filePath;
  final String displayName;
  final int orderIndex;

  /// User-entered end timestamp string (e.g. "00:05", "01:23.500", or null)
  final String? userEndTimestampInput;

  /// Calculated start time in milliseconds from video start
  final int startMs;

  /// Calculated end time in milliseconds from video start
  final int endMs;

  /// Calculated duration in milliseconds (endMs - startMs)
  final int durationMs;

  /// Image fit/display mode for the frame
  final ImageFitMode fitMode;

  /// Validation warning or error message, if any (e.g. "Overlaps previous cut")
  final String? validationError;

  const ImageItem({
    required this.id,
    required this.filePath,
    required this.displayName,
    required this.orderIndex,
    this.userEndTimestampInput,
    this.startMs = 0,
    this.endMs = 0,
    this.durationMs = 0,
    this.fitMode = ImageFitMode.fit,
    this.validationError,
  });

  ImageItem copyWith({
    String? id,
    String? filePath,
    String? displayName,
    int? orderIndex,
    String? userEndTimestampInput,
    int? startMs,
    int? endMs,
    int? durationMs,
    ImageFitMode? fitMode,
    String? validationError,
    bool clearValidationError = false,
  }) {
    return ImageItem(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      displayName: displayName ?? this.displayName,
      orderIndex: orderIndex ?? this.orderIndex,
      userEndTimestampInput:
          userEndTimestampInput ?? this.userEndTimestampInput,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      durationMs: durationMs ?? this.durationMs,
      fitMode: fitMode ?? this.fitMode,
      validationError:
          clearValidationError ? null : (validationError ?? this.validationError),
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
          userEndTimestampInput == other.userEndTimestampInput &&
          startMs == other.startMs &&
          endMs == other.endMs &&
          durationMs == other.durationMs &&
          fitMode == other.fitMode &&
          validationError == other.validationError;

  @override
  int get hashCode =>
      id.hashCode ^
      filePath.hashCode ^
      displayName.hashCode ^
      orderIndex.hashCode ^
      userEndTimestampInput.hashCode ^
      startMs.hashCode ^
      endMs.hashCode ^
      durationMs.hashCode ^
      fitMode.hashCode ^
      validationError.hashCode;

  @override
  String toString() {
    return 'ImageItem(order: $orderIndex, name: $displayName, start: ${startMs}ms, end: ${endMs}ms, dur: ${durationMs}ms)';
  }
}
