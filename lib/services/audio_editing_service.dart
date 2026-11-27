import 'package:uuid/uuid.dart';
import '../models/audio_clip_item.dart';

class AudioEditingService {
  static const _uuid = Uuid();

  static List<AudioClipItem> appendAudioClip({
    required List<AudioClipItem> existingClips,
    required String filePath,
    required String fileName,
    required int durationMs,
    int? customStartMs,
  }) {
    final defaultStart = existingClips.isEmpty ? 0 : existingClips.map((c) => c.endTimelineMs).reduce((a, b) => a > b ? a : b);
    final startMs = customStartMs != null ? customStartMs.clamp(0, 3600000) : defaultStart;
    final newClip = AudioClipItem(
      id: _uuid.v4(),
      filePath: filePath,
      fileName: fileName,
      startTimelineMs: startMs,
      durationMs: durationMs,
      sourceDurationMs: durationMs,
      volume: 1.0,
      orderIndex: existingClips.length,
    );
    return [...existingClips, newClip];
  }

  static List<AudioClipItem>? splitAudioClipAt({
    required List<AudioClipItem> clips,
    required int playheadMs,
  }) {
    final idx = clips.indexWhere((c) => playheadMs > c.startTimelineMs + 100 && playheadMs < c.endTimelineMs - 100);
    if (idx < 0) return null;

    final target = clips[idx];
    final splitOffset = playheadMs - target.startTimelineMs;

    final partA = target.copyWith(
      fileName: '${target.fileName} (Part 1)',
      durationMs: splitOffset,
    );

    final partB = AudioClipItem(
      id: _uuid.v4(),
      filePath: target.filePath,
      fileName: '${target.fileName} (Part 2)',
      startTimelineMs: playheadMs,
      fileStartOffsetMs: target.fileStartOffsetMs + splitOffset,
      durationMs: target.durationMs - splitOffset,
      sourceDurationMs: target.sourceDurationMs,
      volume: target.volume,
      orderIndex: target.orderIndex + 1,
    );

    final updated = List<AudioClipItem>.from(clips);
    updated[idx] = partA;
    updated.insert(idx + 1, partB);

    for (int i = 0; i < updated.length; i++) {
      updated[i] = updated[i].copyWith(orderIndex: i);
    }
    return updated;
  }

  static List<AudioClipItem>? splitSpecificClip({
    required List<AudioClipItem> clips,
    required String clipId,
    int? splitTimelineMs,
  }) {
    final idx = clips.indexWhere((c) => c.id == clipId);
    if (idx < 0) return null;
    final target = clips[idx];
    final targetSplitMs = splitTimelineMs ?? (target.startTimelineMs + (target.durationMs ~/ 2));
    if (targetSplitMs <= target.startTimelineMs + 100 || targetSplitMs >= target.endTimelineMs - 100) {
      return null;
    }
    return splitAudioClipAt(clips: clips, playheadMs: targetSplitMs);
  }

  static List<AudioClipItem> deleteAudioClip({
    required List<AudioClipItem> clips,
    required String clipId,
    bool ripple = true,
  }) {
    final filtered = clips.where((c) => c.id != clipId).toList();
    if (!ripple || filtered.isEmpty) return filtered;

    final updated = <AudioClipItem>[];
    int curMs = 0;
    for (int i = 0; i < filtered.length; i++) {
      final c = filtered[i];
      updated.add(c.copyWith(
        startTimelineMs: curMs,
        orderIndex: i,
      ));
      curMs += c.durationMs;
    }
    return updated;
  }

  static List<AudioClipItem> updateVolume({
    required List<AudioClipItem> clips,
    required String clipId,
    required double volume,
  }) {
    return clips.map((c) => c.id == clipId ? c.copyWith(volume: volume.clamp(0.0, 1.5)) : c).toList();
  }

  static List<AudioClipItem> trimClipEnd({
    required List<AudioClipItem> clips,
    required String clipId,
    required int newDurationMs,
  }) {
    final clamped = newDurationMs.clamp(200, 3600000);
    return clips.map((c) => c.id == clipId ? c.copyWith(durationMs: clamped) : c).toList();
  }

  static List<AudioClipItem> trimClipStart({
    required List<AudioClipItem> clips,
    required String clipId,
    required int newStartTimelineMs,
  }) {
    return clips.map((c) {
      if (c.id != clipId) return c;
      final currentEndMs = c.endTimelineMs;
      final clampedStartMs = newStartTimelineMs.clamp(0, currentEndMs - 200);
      final deltaMs = clampedStartMs - c.startTimelineMs;
      final newFileOffset = (c.fileStartOffsetMs + deltaMs).clamp(0, 3600000);
      final newDuration = currentEndMs - clampedStartMs;
      return c.copyWith(
        startTimelineMs: clampedStartMs,
        fileStartOffsetMs: newFileOffset,
        durationMs: newDuration,
      );
    }).toList();
  }

  static List<AudioClipItem> moveClipStart({
    required List<AudioClipItem> clips,
    required String clipId,
    required int newStartMs,
  }) {
    final updated = clips.map((c) => c.id == clipId ? c.copyWith(startTimelineMs: newStartMs < 0 ? 0 : newStartMs) : c).toList();
    updated.sort((a, b) => a.startTimelineMs.compareTo(b.startTimelineMs));
    for (int i = 0; i < updated.length; i++) {
      updated[i] = updated[i].copyWith(orderIndex: i);
    }
    return updated;
  }

  /// Sets an exact [sourceStartMs..sourceEndMs] range within the underlying audio file.
  static List<AudioClipItem> updateSourceRange({
    required List<AudioClipItem> clips,
    required String clipId,
    required int sourceStartMs,
    required int sourceEndMs,
  }) {
    return clips.map((c) {
      if (c.id != clipId) return c;
      final maxDur = c.sourceDurationMs;
      final upperBound = (maxDur != null && maxDur > 0) ? maxDur : sourceEndMs;
      final clampedStart = sourceStartMs.clamp(0, (upperBound - 200).clamp(0, upperBound));
      final clampedEnd = sourceEndMs.clamp(clampedStart + 200, upperBound);
      return c.copyWith(
        fileStartOffsetMs: clampedStart,
        durationMs: clampedEnd - clampedStart,
        sourceDurationMs: c.sourceDurationMs ?? clampedEnd,
      );
    }).toList();
  }

  static AudioClipItem? findClipAt(List<AudioClipItem> clips, int timelineMs) {
    for (final clip in clips) {
      if (timelineMs >= clip.startTimelineMs && timelineMs < clip.endTimelineMs) return clip;
    }
    return null;
  }
}
