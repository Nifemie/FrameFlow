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

  /// Trims or extends clip end boundary and ripples all subsequent clips forward/backward,
  /// preserving their individual durations so subsequent clips shift forward instead of hiding behind.
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
          userEndTimestampInput: (clampedEnd / 1000.0).toStringAsFixed(2),
        ));
      } else {
        String? newStart;
        if (img.userStartTimestampInput != null) {
          final sMs = TimeParser.parseToMs(img.userStartTimestampInput);
          if (sMs != null) newStart = ((sMs + deltaMs) / 1000.0).toStringAsFixed(2);
        }
        String? newEnd;
        if (img.userEndTimestampInput != null) {
          final eMs = TimeParser.parseToMs(img.userEndTimestampInput);
          if (eMs != null) newEnd = ((eMs + deltaMs) / 1000.0).toStringAsFixed(2);
        } else {
          newEnd = ((img.endMs + deltaMs) / 1000.0).toStringAsFixed(2);
        }
        updated.add(img.copyWith(
          userStartTimestampInput: newStart,
          userEndTimestampInput: newEnd,
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
