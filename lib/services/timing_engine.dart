import '../core/utils/time_parser.dart';
import '../models/image_item.dart';

/// The core mathematical timing and synchronization engine for FrameFlow.
/// Calculates frame/millisecond boundaries, propagates timing updates across clips,
/// and handles automatic voice-over snapping.
class TimingEngine {
  /// Default duration in milliseconds assigned to an image if no timestamp is specified.
  static const int defaultImageDurationMs = 5000;

  /// Recalculates the timing sequence for an entire list of images.
  /// 
  /// Rules:
  /// 1. Image 0 always starts at 0ms.
  /// 2. Image N starts exactly at Image (N-1)'s endMs.
  /// 3. If an image has a valid [userEndTimestampInput], its endMs is parsed from it.
  /// 4. If an image lacks an end timestamp:
  ///    - If it's the last image and [voiceOverDurationMs] is provided, it automatically
  ///      extends to [voiceOverDurationMs].
  ///    - Otherwise, it gets [defaultImageDurationMs].
  /// 5. If [snapFinalImageToAudio] is true and [voiceOverDurationMs] > 0, the final image
  ///    always ends at [voiceOverDurationMs].
  static List<ImageItem> calculateSequence({
    required List<ImageItem> images,
    int? voiceOverDurationMs,
    bool snapFinalImageToAudio = true,
  }) {
    if (images.isEmpty) return const [];

    final updated = <ImageItem>[];
    int currentStartMs = 0;

    for (int i = 0; i < images.length; i++) {
      final item = images[i];
      final isLast = (i == images.length - 1);

      String? validationError;
      int endMs;

      // Check user input
      final parsedUserEnd = TimeParser.parseToMs(item.userEndTimestampInput);

      if (isLast && snapFinalImageToAudio && voiceOverDurationMs != null && voiceOverDurationMs > 0) {
        // Last image snaps automatically to audio duration
        if (voiceOverDurationMs <= currentStartMs) {
          // Edge case: audio is shorter than preceding images
          endMs = currentStartMs + defaultImageDurationMs;
          validationError = 'Image exceeds voice-over duration (${TimeParser.formatStandard(voiceOverDurationMs)})';
        } else {
          endMs = voiceOverDurationMs;
        }
      } else if (parsedUserEnd != null) {
        endMs = parsedUserEnd;
        if (endMs <= currentStartMs) {
          validationError = 'End time must be after start time (${TimeParser.formatDetailed(currentStartMs)})';
        } else if (voiceOverDurationMs != null && voiceOverDurationMs > 0 && endMs > voiceOverDurationMs) {
          validationError = 'Timestamp exceeds audio duration (${TimeParser.formatStandard(voiceOverDurationMs)})';
        }
      } else {
        // No timestamp specified
        if (isLast && voiceOverDurationMs != null && voiceOverDurationMs > currentStartMs) {
          endMs = voiceOverDurationMs;
        } else {
          endMs = currentStartMs + (item.durationMs > 0 ? item.durationMs : defaultImageDurationMs);
        }
      }

      // Compute duration
      final durationMs = endMs > currentStartMs ? (endMs - currentStartMs) : 0;

      updated.add(item.copyWith(
        orderIndex: i,
        startMs: currentStartMs,
        endMs: endMs,
        durationMs: durationMs,
        validationError: validationError,
        clearValidationError: validationError == null,
      ));

      currentStartMs = endMs;
    }

    return updated;
  }

  /// Updates an individual image's timestamp and automatically recalculates all subsequent clips.
  static List<ImageItem> updateImageTimestamp({
    required List<ImageItem> images,
    required String imageId,
    required String? newTimestampInput,
    int? voiceOverDurationMs,
    bool snapFinalImageToAudio = true,
  }) {
    final modified = images.map((img) {
      if (img.id == imageId) {
        return img.copyWith(userEndTimestampInput: newTimestampInput);
      }
      return img;
    }).toList();

    return calculateSequence(
      images: modified,
      voiceOverDurationMs: voiceOverDurationMs,
      snapFinalImageToAudio: snapFinalImageToAudio,
    );
  }

  /// Bulk assigns a list of timestamp strings to images in sequential order.
  static List<ImageItem> applyBulkTimestamps({
    required List<ImageItem> images,
    required List<String> timestampList,
    int? voiceOverDurationMs,
    bool snapFinalImageToAudio = true,
  }) {
    final modified = <ImageItem>[];

    for (int i = 0; i < images.length; i++) {
      final img = images[i];
      final stamp = (i < timestampList.length) ? timestampList[i].trim() : null;
      modified.add(img.copyWith(userEndTimestampInput: stamp));
    }

    return calculateSequence(
      images: modified,
      voiceOverDurationMs: voiceOverDurationMs,
      snapFinalImageToAudio: snapFinalImageToAudio,
    );
  }

  /// Binary search to find which image is currently active at [playheadMs].
  /// Returns index in [images], or -1 if outside bounds.
  static int findActiveImageIndex(List<ImageItem> images, int playheadMs) {
    if (images.isEmpty) return -1;
    if (playheadMs < 0) return 0;
    if (playheadMs >= images.last.endMs) return images.length - 1;

    int low = 0;
    int high = images.length - 1;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final item = images[mid];

      if (playheadMs >= item.startMs && playheadMs < item.endMs) {
        return mid;
      } else if (playheadMs < item.startMs) {
        high = mid - 1;
      } else {
        low = mid + 1;
      }
    }

    return (low < images.length) ? low : images.length - 1;
  }
}
