import 'dart:math';

import '../models/audio_clip_item.dart';
import '../models/image_item.dart';
import '../models/project.dart';
import '../models/text_overlay_item.dart';

/// Slices a [Project] to a specific `[rangeStartMs, rangeEndMs]` window
/// so that the existing FFmpeg rendering pipeline exports only that exact
/// portion with frame-accurate boundaries, video offsets, audio, and overlays.
class ProjectSliceService {
  static Project sliceProject(Project project, int rangeStartMs, int rangeEndMs) {
    final start = max(0, rangeStartMs);
    final end = max(start + 1, rangeEndMs);

    // 1. Slice visual clips (images, videos, color backgrounds)
    final slicedImages = <ImageItem>[];
    int orderIdx = 0;
    for (final img in project.images) {
      if (img.endMs <= start || img.startMs >= end) continue;
      final clippedStart = max(img.startMs, start);
      final clippedEnd = min(img.endMs, end);
      if (clippedEnd <= clippedStart) continue;

      final newStart = clippedStart - start;
      final newEnd = clippedEnd - start;
      final newDur = newEnd - newStart;
      final trimLeftMs = clippedStart - img.startMs;

      final newSourceStart = img.isVideo
          ? img.sourceStartOffsetMs + trimLeftMs
          : img.sourceStartOffsetMs;

      slicedImages.add(img.copyWith(
        orderIndex: orderIdx++,
        startMs: newStart,
        endMs: newEnd,
        durationMs: newDur,
        sourceStartOffsetMs: newSourceStart,
        userStartTimestampInput: (newStart / 1000.0).toStringAsFixed(3),
        userEndTimestampInput: (newEnd / 1000.0).toStringAsFixed(3),
      ));
    }

    // 2. Slice audio clips & voice-over
    final slicedAudio = <AudioClipItem>[];
    int audioOrder = 0;
    for (final clip in project.effectiveAudioClips) {
      if (clip.endTimelineMs <= start || clip.startTimelineMs >= end) continue;
      final clippedStart = max(clip.startTimelineMs, start);
      final clippedEnd = min(clip.endTimelineMs, end);
      if (clippedEnd <= clippedStart) continue;

      final newStart = clippedStart - start;
      final newDur = clippedEnd - clippedStart;
      final trimLeftMs = clippedStart - clip.startTimelineMs;

      slicedAudio.add(clip.copyWith(
        orderIndex: audioOrder++,
        startTimelineMs: newStart,
        durationMs: newDur,
        fileStartOffsetMs: clip.fileStartOffsetMs + trimLeftMs,
      ));
    }

    // 3. Slice text overlays
    final slicedText = <TextOverlayItem>[];
    for (final overlay in project.textOverlays) {
      if (overlay.endMs <= start || overlay.startMs >= end) continue;
      final clippedStart = max(overlay.startMs, start);
      final clippedEnd = min(overlay.endMs, end);
      if (clippedEnd <= clippedStart) continue;

      slicedText.add(overlay.copyWith(
        startMs: clippedStart - start,
        durationMs: clippedEnd - clippedStart,
      ));
    }

    return project.copyWith(
      images: slicedImages,
      audioClips: slicedAudio,
      clearVoiceOver: slicedAudio.isEmpty,
      textOverlays: slicedText,
    );
  }
}
