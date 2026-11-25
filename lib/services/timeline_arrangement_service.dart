import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../models/image_item.dart';
import 'timing_engine.dart';
import 'video_metadata_service.dart';

class TimelineArrangementService {
  static const _uuid = Uuid();

  static List<ImageItem> _recalcTrackDurations(List<ImageItem> images, String trackId, int? voiceOverDurationMs) {
    final trackClips = images.where((i) => i.trackId == trackId).toList();
    final otherClips = images.where((i) => i.trackId != trackId).toList();
    if (trackClips.isEmpty) return images;

    int currentMs = 0;
    final updatedTrackClips = <ImageItem>[];
    for (int i = 0; i < trackClips.length; i++) {
      final clip = trackClips[i];
      final dur = clip.durationMs > 0 ? clip.durationMs : 5000;
      final start = currentMs, end = start + dur;
      updatedTrackClips.add(clip.copyWith(
        orderIndex: i, startMs: start, endMs: end, durationMs: dur,
        userStartTimestampInput: (start / 1000.0).toStringAsFixed(2),
        userEndTimestampInput: (end / 1000.0).toStringAsFixed(2),
        clearValidationError: true,
      ));
      currentMs = end;
    }
    return [...otherClips, ...updatedTrackClips];
  }

  /// Snaps [targetMs] to the nearest point in [targets] if within [thresholdPx] at [pxPerSec].
  /// Returns `(snappedMs, matchedSnapLineMs)`.
  static (int, int?) snapToTargets({
    required int targetMs,
    required List<int> targets,
    required double pxPerSec,
    bool enabled = true,
    double thresholdPx = 12.0,
  }) {
    if (!enabled || targets.isEmpty || pxPerSec <= 0) return (targetMs, null);
    final thresholdMs = (thresholdPx / pxPerSec) * 1000.0;
    int bestMs = targetMs;
    double bestDist = thresholdMs + 1.0;
    int? snapLine;
    for (final t in targets) {
      final d = (targetMs - t).abs().toDouble();
      if (d <= thresholdMs && d < bestDist) {
        bestDist = d;
        bestMs = t;
        snapLine = t;
      }
    }
    return (bestMs, snapLine);
  }

  /// Packs clips sequentially from 00:00 (left) removing all blank spaces.
  static List<ImageItem> autoArrangeFromLeft({
    required List<ImageItem> images,
    String? trackId,
    int? voiceOverDurationMs,
  }) {
    if (images.isEmpty) return const [];
    final trackIds = trackId != null ? {trackId} : images.map((i) => i.trackId).toSet();
    final result = <ImageItem>[];
    for (final img in images) {
      if (!trackIds.contains(img.trackId)) result.add(img);
    }
    for (final tid in trackIds) {
      final trackClips = images.where((i) => i.trackId == tid).toList()
        ..sort((a, b) => a.startMs.compareTo(b.startMs));
      result.addAll(_recalcTrackDurations(trackClips, tid, voiceOverDurationMs));
    }
    return result;
  }

  static List<ImageItem> moveClipStart({required List<ImageItem> images, required String clipId, required int newStartMs, int? voiceOverDurationMs}) {
    final idx = images.indexWhere((img) => img.id == clipId);
    if (idx < 0) return images;
    final target = images[idx], dur = target.durationMs > 0 ? target.durationMs : 5000;
    final clampedStart = newStartMs.clamp(0, 3600000);
    final startSec = (clampedStart / 1000.0).toStringAsFixed(2);
    final endSec = ((clampedStart + dur) / 1000.0).toStringAsFixed(2);
    final updated = <ImageItem>[];
    for (int i = 0; i < images.length; i++) {
      final img = images[i];
      if (i == idx) {
        updated.add(target.copyWith(
          startMs: clampedStart,
          endMs: clampedStart + dur,
          userStartTimestampInput: startSec,
          userEndTimestampInput: endSec,
          clearValidationError: true,
        ));
      } else if (img.trackId == target.trackId) {
        // Lock other clips on the same track at their existing positions so blank spaces aren't pushed
        updated.add(img.copyWith(
          userStartTimestampInput: img.userStartTimestampInput ?? (img.startMs / 1000.0).toStringAsFixed(2),
          userEndTimestampInput: img.userEndTimestampInput ?? (img.endMs / 1000.0).toStringAsFixed(2),
        ));
      } else {
        updated.add(img);
      }
    }
    updated.sort((a, b) {
      if (a.trackId != b.trackId) return a.trackId.compareTo(b.trackId);
      return a.startMs.compareTo(b.startMs);
    });
    return TimingEngine.calculateSequence(images: updated, voiceOverDurationMs: voiceOverDurationMs, snapFinalImageToAudio: false);
  }

  static List<ImageItem> swapClips({required List<ImageItem> images, required String idA, required String idB, int? voiceOverDurationMs}) {
    final idxA = images.indexWhere((i) => i.id == idA), idxB = images.indexWhere((i) => i.id == idB);
    if (idxA < 0 || idxB < 0 || idxA == idxB) return images;
    final list = List<ImageItem>.from(images);
    final temp = list[idxA];
    list[idxA] = list[idxB];
    list[idxB] = temp;
    var res = _recalcTrackDurations(list, temp.trackId, voiceOverDurationMs);
    if (temp.trackId != list[idxA].trackId) res = _recalcTrackDurations(res, list[idxA].trackId, voiceOverDurationMs);
    return res;
  }

  static List<ImageItem> reorderAndOccupy({required List<ImageItem> images, required String draggedId, required String targetId, required bool insertBefore, int? voiceOverDurationMs}) {
    final dragIdx = images.indexWhere((i) => i.id == draggedId), targetIdx = images.indexWhere((i) => i.id == targetId);
    if (dragIdx < 0 || targetIdx < 0 || dragIdx == targetIdx) return images;

    final dragged = images[dragIdx], target = images[targetIdx];
    final list = List<ImageItem>.from(images)..removeAt(dragIdx);
    final newTargetIdx = list.indexWhere((i) => i.id == targetId);
    final insertIdx = insertBefore ? newTargetIdx : newTargetIdx + 1;
    list.insert(insertIdx.clamp(0, list.length), dragged.copyWith(trackId: target.trackId));

    var res = _recalcTrackDurations(list, target.trackId, voiceOverDurationMs);
    if (dragged.trackId != target.trackId) res = _recalcTrackDurations(res, dragged.trackId, voiceOverDurationMs);
    return res;
  }

  static List<ImageItem> fillGap({required List<ImageItem> images, required int startMs, required int endMs, required String trackId, required bool isColorBg, String? imagePath, Color? color, int? voiceOverDurationMs}) {
    final dur = (endMs - startMs).clamp(200, 3600000);
    final item = ImageItem(
      id: _uuid.v4(), filePath: isColorBg ? 'color_background' : (imagePath ?? ''),
      displayName: isColorBg ? 'Color BG' : p.basename(imagePath ?? 'Image'),
      orderIndex: 0, durationMs: dur, trackId: trackId,
      backgroundColorValue: isColorBg ? (color?.toARGB32() ?? 0xFF1E293B) : null,
      startMs: startMs, endMs: endMs,
      userStartTimestampInput: (startMs / 1000.0).toStringAsFixed(2),
      userEndTimestampInput: (endMs / 1000.0).toStringAsFixed(2),
    );
    final updated = List<ImageItem>.from(images)..add(item);
    updated.sort((a, b) {
      if (a.trackId != b.trackId) return a.trackId.compareTo(b.trackId);
      return a.startMs.compareTo(b.startMs);
    });
    for (int i = 0; i < updated.length; i++) { updated[i] = updated[i].copyWith(orderIndex: i); }
    return TimingEngine.calculateSequence(images: updated, voiceOverDurationMs: voiceOverDurationMs, snapFinalImageToAudio: false);
  }

  static List<ImageItem> fillGapWithClip({required List<ImageItem> images, required String clipId, required int startMs, required String targetTrackId, int? voiceOverDurationMs}) {
    final idx = images.indexWhere((i) => i.id == clipId);
    if (idx < 0) return images;
    final clip = images[idx], dur = clip.durationMs > 0 ? clip.durationMs : 5000;
    final list = <ImageItem>[];
    for (int i = 0; i < images.length; i++) {
      if (i == idx) continue;
      final other = images[i];
      if (other.trackId == targetTrackId) {
        list.add(other.copyWith(
          userStartTimestampInput: other.userStartTimestampInput ?? (other.startMs / 1000.0).toStringAsFixed(2),
          userEndTimestampInput: other.userEndTimestampInput ?? (other.endMs / 1000.0).toStringAsFixed(2),
        ));
      } else {
        list.add(other);
      }
    }
    final movedClip = clip.copyWith(
      trackId: targetTrackId, startMs: startMs, endMs: startMs + dur, durationMs: dur,
      userStartTimestampInput: (startMs / 1000.0).toStringAsFixed(2),
      userEndTimestampInput: ((startMs + dur) / 1000.0).toStringAsFixed(2),
      clearValidationError: true,
    );
    list.add(movedClip);
    list.sort((a, b) {
      if (a.trackId != b.trackId) return a.trackId.compareTo(b.trackId);
      return a.startMs.compareTo(b.startMs);
    });
    for (int i = 0; i < list.length; i++) { list[i] = list[i].copyWith(orderIndex: i); }
    return TimingEngine.calculateSequence(images: list, voiceOverDurationMs: voiceOverDurationMs, snapFinalImageToAudio: false);
  }

  static List<ImageItem> insertAfterClip({required List<ImageItem> images, required ImageItem afterClip, required bool isColorBg, String? imagePath, Color? color, int? voiceOverDurationMs}) {
    final trackClips = images.where((i) => i.trackId == afterClip.trackId).toList()
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    final trIdx = trackClips.indexWhere((i) => i.id == afterClip.id);
    final nextClip = (trIdx >= 0 && trIdx + 1 < trackClips.length) ? trackClips[trIdx + 1] : null;

    final rawIdx = images.indexWhere((i) => i.id == afterClip.id);
    final insertIdx = rawIdx >= 0 ? rawIdx + 1 : images.length;

    String? startSec, endSec;
    int dur = 3000;
    if (nextClip != null && nextClip.startMs > afterClip.endMs + 100) {
      startSec = (afterClip.endMs / 1000.0).toStringAsFixed(2);
      endSec = (nextClip.startMs / 1000.0).toStringAsFixed(2);
      dur = nextClip.startMs - afterClip.endMs;
    } else if (imagePath != null && AppConstants.isVideoFile(imagePath)) {
      final cachedDur = VideoMetadataService.getCachedDuration(imagePath);
      if (cachedDur != null && cachedDur > 0) {
        dur = cachedDur;
      }
    }

    final item = ImageItem(
      id: _uuid.v4(), filePath: isColorBg ? 'color_background' : (imagePath ?? ''),
      displayName: isColorBg ? 'Color BG' : p.basename(imagePath ?? 'Image'),
      orderIndex: insertIdx, durationMs: dur, trackId: afterClip.trackId,
      backgroundColorValue: isColorBg ? (color?.toARGB32() ?? 0xFF1E293B) : null,
      userStartTimestampInput: startSec, userEndTimestampInput: endSec,
    );
    final updated = List<ImageItem>.from(images)..insert(insertIdx, item);
    return TimingEngine.calculateSequence(images: updated, voiceOverDurationMs: voiceOverDurationMs, snapFinalImageToAudio: false);
  }
}