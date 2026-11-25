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

  static List<ImageItem> moveClipStart({required List<ImageItem> images, required String clipId, required int newStartMs, int? voiceOverDurationMs}) {
    final idx = images.indexWhere((img) => img.id == clipId);
    if (idx < 0) return images;
    final target = images[idx], dur = target.durationMs > 0 ? target.durationMs : 5000;
    final startSec = (newStartMs.clamp(0, 3600000) / 1000.0).toStringAsFixed(2);
    final endSec = ((newStartMs + dur) / 1000.0).toStringAsFixed(2);
    final updated = List<ImageItem>.from(images);
    updated[idx] = target.copyWith(userStartTimestampInput: startSec, userEndTimestampInput: endSec);
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
    final list = List<ImageItem>.from(images)..removeAt(idx);
    final movedClip = clip.copyWith(
      trackId: targetTrackId, startMs: startMs, endMs: startMs + dur, durationMs: dur,
      userStartTimestampInput: (startMs / 1000.0).toStringAsFixed(2),
      userEndTimestampInput: ((startMs + dur) / 1000.0).toStringAsFixed(2),
    );
    list.add(movedClip);
    list.sort((a, b) => a.startMs.compareTo(b.startMs));
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