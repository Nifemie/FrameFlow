import 'package:uuid/uuid.dart';

import '../core/utils/time_parser.dart';
import '../models/image_item.dart';
import 'timing_engine.dart';

/// Service dedicated to clip-level operations: splitting, cutting, deleting, and duplicating.
class ClipEditingService {
  static const _uuid = Uuid();

  /// Splits the image clip currently beneath [playheadMs] into two independent clips.
  /// Returns null if playhead is not inside a clip or is too close (<100ms) to an edge.
  static List<ImageItem>? splitClipAt({
    required List<ImageItem> images,
    required int playheadMs,
    int? voiceOverDurationMs,
  }) {
    if (images.isEmpty) return null;

    final activeIdx = TimingEngine.findActiveImageIndex(images, playheadMs);
    if (activeIdx < 0 || activeIdx >= images.length) return null;

    final target = images[activeIdx];
    // Prevent zero-length slices (must be at least 100ms from edges)
    if (playheadMs <= target.startMs + 100 || playheadMs >= target.endMs - 100) {
      return null;
    }

    final splitTimeStr = TimeParser.formatDetailed(playheadMs);
    final splitOffsetMs = playheadMs - target.startMs;

    final partA = target.copyWith(
      displayName: _cleanPartName(target.displayName, 1),
      userEndTimestampInput: splitTimeStr,
    );

    final partBEndStr = target.userEndTimestampInput ?? TimeParser.formatDetailed(target.endMs);

    final partB = ImageItem(
      id: _uuid.v4(),
      filePath: target.filePath,
      displayName: _cleanPartName(target.displayName, 2),
      orderIndex: target.orderIndex + 1,
      userEndTimestampInput: partBEndStr,
      fitMode: target.fitMode,
      trackId: target.trackId,
      backgroundColorValue: target.backgroundColorValue,
      sourceStartOffsetMs: target.sourceStartOffsetMs + splitOffsetMs,
      sourceDurationMs: target.sourceDurationMs,
      mediaWidth: target.mediaWidth,
      mediaHeight: target.mediaHeight,
      transform: target.transform,
      animations: target.animations,
    );

    final updated = List<ImageItem>.from(images);
    updated[activeIdx] = partA;
    updated.insert(activeIdx + 1, partB);

    return TimingEngine.calculateSequence(
      images: updated,
      voiceOverDurationMs: voiceOverDurationMs,
    );
  }

  /// Duplicates a clip and inserts it immediately after the original.
  static List<ImageItem> duplicateClip({
    required List<ImageItem> images,
    required String clipId,
    int? voiceOverDurationMs,
  }) {
    final idx = images.indexWhere((img) => img.id == clipId);
    if (idx < 0) return images;

    final original = images[idx];
    final copy = ImageItem(
      id: _uuid.v4(),
      filePath: original.filePath,
      displayName: '${original.displayName} (Copy)',
      orderIndex: original.orderIndex + 1,
      userEndTimestampInput: null,
      fitMode: original.fitMode,
      trackId: original.trackId,
      backgroundColorValue: original.backgroundColorValue,
    );

    final updated = List<ImageItem>.from(images);
    updated.insert(idx + 1, copy);

    return TimingEngine.calculateSequence(
      images: updated,
      voiceOverDurationMs: voiceOverDurationMs,
    );
  }

  /// Removes a clip from the sequence with ripple adjustment.
  static List<ImageItem> deleteClip({
    required List<ImageItem> images,
    required String clipId,
    bool ripple = true,
    int? voiceOverDurationMs,
  }) {
    if (!ripple) {
      return deleteClipPreservingGaps(
        images: images,
        clipIdsToDelete: {clipId},
        voiceOverDurationMs: voiceOverDurationMs,
      );
    }
    final filtered = images.where((img) => img.id != clipId).toList();
    return TimingEngine.calculateSequence(
      images: filtered,
      voiceOverDurationMs: voiceOverDurationMs,
    );
  }

  /// Removes one or multiple clips while leaving blank empty regions (gaps) in their place,
  /// preserving the tracks and timeline positioning of all other clips.
  static List<ImageItem> deleteClipPreservingGaps({
    required List<ImageItem> images,
    required Set<String> clipIdsToDelete,
    int? voiceOverDurationMs,
  }) {
    if (images.isEmpty || clipIdsToDelete.isEmpty) return images;

    final updated = <ImageItem>[];
    for (int i = 0; i < images.length; i++) {
      final img = images[i];
      if (clipIdsToDelete.contains(img.id)) {
        // Skip deleted clip, leaving its exact space as a blank gap
        continue;
      }

      // Lock existing start and end times so adjacent clips do not ripple
      final startSec = (img.startMs / 1000.0).toStringAsFixed(2);
      final endSec = (img.endMs / 1000.0).toStringAsFixed(2);
      updated.add(img.copyWith(
        userStartTimestampInput: startSec,
        userEndTimestampInput: endSec,
        clearValidationError: true,
      ));
    }

    return TimingEngine.calculateSequence(
      images: updated,
      voiceOverDurationMs: voiceOverDurationMs,
      snapFinalImageToAudio: false,
    );
  }

  /// Trims or extends clip end boundary.
  /// If a blank gap exists immediately after [clipId], extending consumes the blank gap first
  /// without moving subsequent clips; only overflow beyond the gap pushes subsequent clips forward.
  static List<ImageItem> rippleTrimClipEnd({
    required List<ImageItem> images,
    required String clipId,
    required int newEndMs,
    int? voiceOverDurationMs,
  }) {
    final idx = images.indexWhere((img) => img.id == clipId);
    if (idx < 0) return images;

    final target = images[idx];
    final minEnd = target.startMs + 200;
    final clampedEnd = newEndMs < minEnd ? minEnd : newEndMs;
    final deltaMs = clampedEnd - target.endMs;
    if (deltaMs == 0) return images;

    // Find the immediate next clip on the same track to see if there is a blank gap after target
    ImageItem? nextOnTrack;
    for (int i = idx + 1; i < images.length; i++) {
      if (images[i].trackId == target.trackId) {
        nextOnTrack = images[i];
        break;
      }
    }

    final gapAfterTarget = nextOnTrack != null ? (nextOnTrack.startMs - target.endMs).clamp(0, 36000000) : 0;

    // If extending (deltaMs > 0): consume blank gap first, only push subsequent clips by overflow.
    // If shrinking (deltaMs < 0): if there was already a blank gap, keep subsequent clips in place;
    // if adjacent (gapAfterTarget == 0), ripple-pull subsequent clips backward.
    final int pushDeltaMs;
    if (deltaMs > 0) {
      pushDeltaMs = deltaMs > gapAfterTarget ? (deltaMs - gapAfterTarget) : 0;
    } else {
      pushDeltaMs = gapAfterTarget > 0 ? 0 : deltaMs;
    }

    final updated = <ImageItem>[];
    for (int i = 0; i < images.length; i++) {
      final img = images[i];
      if (img.trackId != target.trackId) {
        updated.add(img);
        continue;
      }
      if (i < idx) {
        updated.add(img);
      } else if (i == idx) {
        updated.add(img.copyWith(
          userStartTimestampInput: img.userStartTimestampInput ?? (img.startMs / 1000.0).toStringAsFixed(2),
          userEndTimestampInput: (clampedEnd / 1000.0).toStringAsFixed(2),
        ));
      } else {
        if (pushDeltaMs == 0) {
          // Lock subsequent clip at its exact position so only the blank gap shrinks/widens
          updated.add(img.copyWith(
            userStartTimestampInput: img.userStartTimestampInput ?? (img.startMs / 1000.0).toStringAsFixed(2),
            userEndTimestampInput: img.userEndTimestampInput ?? (img.endMs / 1000.0).toStringAsFixed(2),
          ));
        } else {
          final shiftedStart = img.startMs + pushDeltaMs;
          final shiftedEnd = img.endMs + pushDeltaMs;
          updated.add(img.copyWith(
            userStartTimestampInput: (shiftedStart / 1000.0).toStringAsFixed(2),
            userEndTimestampInput: (shiftedEnd / 1000.0).toStringAsFixed(2),
          ));
        }
      }
    }

    return TimingEngine.calculateSequence(
      images: updated,
      voiceOverDurationMs: voiceOverDurationMs,
      snapFinalImageToAudio: false,
    );
  }

  /// Trims or extends clip start boundary from the left edge.
  /// Expanding left into a blank gap reduces only the blank gap; dragging further past the
  /// previous clip's end pushes [clipId]'s end and subsequent clips forward.
  static List<ImageItem> trimClipStart({
    required List<ImageItem> images,
    required String clipId,
    required int newStartMs,
    int? voiceOverDurationMs,
  }) {
    final idx = images.indexWhere((img) => img.id == clipId);
    if (idx < 0) return images;

    final target = images[idx];
    ImageItem? prevOnTrack;
    for (int i = idx - 1; i >= 0; i--) {
      if (images[i].trackId == target.trackId) {
        prevOnTrack = images[i];
        break;
      }
    }

    final minAllowedStart = prevOnTrack != null ? prevOnTrack.endMs : 0;
    final maxAllowedStart = target.endMs - 200;

    final int actualStartMs;
    final int overflowRightMs;
    if (newStartMs < minAllowedStart) {
      // Blank gap is fully covered; excess expansion pushes this clip's end & subsequent clips forward
      actualStartMs = minAllowedStart;
      overflowRightMs = minAllowedStart - newStartMs;
    } else {
      actualStartMs = newStartMs > maxAllowedStart ? maxAllowedStart : newStartMs;
      overflowRightMs = 0;
    }

    // Check gap after target if overflowRightMs > 0
    ImageItem? nextOnTrack;
    for (int i = idx + 1; i < images.length; i++) {
      if (images[i].trackId == target.trackId) {
        nextOnTrack = images[i];
        break;
      }
    }
    final gapAfterTarget = nextOnTrack != null ? (nextOnTrack.startMs - target.endMs).clamp(0, 36000000) : 0;
    final pushNextMs = overflowRightMs > gapAfterTarget ? (overflowRightMs - gapAfterTarget) : 0;

    final updated = <ImageItem>[];
    for (int i = 0; i < images.length; i++) {
      final img = images[i];
      if (img.trackId != target.trackId || i < idx) {
        updated.add(img);
        continue;
      }
      if (i == idx) {
        final newEnd = target.endMs + overflowRightMs;
        updated.add(img.copyWith(
          userStartTimestampInput: (actualStartMs / 1000.0).toStringAsFixed(2),
          userEndTimestampInput: (newEnd / 1000.0).toStringAsFixed(2),
        ));
      } else {
        final shiftedStart = img.startMs + pushNextMs;
        final shiftedEnd = img.endMs + pushNextMs;
        updated.add(img.copyWith(
          userStartTimestampInput: (shiftedStart / 1000.0).toStringAsFixed(2),
          userEndTimestampInput: (shiftedEnd / 1000.0).toStringAsFixed(2),
        ));
      }
    }

    return TimingEngine.calculateSequence(
      images: updated,
      voiceOverDurationMs: voiceOverDurationMs,
      snapFinalImageToAudio: false,
    );
  }

  static String _cleanPartName(String original, int partNum) {
    final base = original.replaceAll(RegExp(r'\s*\(Part\s*\d+\)$'), '');
    return '$base (Part $partNum)';
  }
}
