import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/utils/time_parser.dart';
import '../features/timestamps/services/csv_service.dart';
import '../models/asset_animation.dart';
import '../models/asset_transform.dart';
import '../models/audio_clip_item.dart';
import '../models/image_item.dart';
import '../models/project.dart';
import '../models/text_overlay_item.dart';
import '../models/timeline_gap.dart';
import '../models/timeline_marker.dart';
import '../models/timeline_track_item.dart';
import '../models/voice_over.dart';
import '../services/alignment_service.dart';
import '../services/asset_animation_service.dart';
import '../services/animation_randomisation_engine.dart';
import '../services/audio_editing_service.dart';
import '../services/clip_editing_service.dart';
import '../services/text_editing_service.dart';
import '../services/timeline_arrangement_service.dart';
import '../services/timing_engine.dart';
import '../services/undo_redo_manager.dart';
import '../services/video_metadata_service.dart';

class ProjectNotifier extends StateNotifier<Project> {
  static const _uuid = Uuid();
  final UndoRedoManager _undoRedo = UndoRedoManager();

  ProjectNotifier() : super(Project(id: _uuid.v4(), name: 'Untitled Project'));

  bool get canUndo => _undoRedo.canUndo;
  bool get canRedo => _undoRedo.canRedo;
  bool undo() { final p = _undoRedo.undo(state); if (p != null) { state = p; return true; } return false; }
  bool redo() { final n = _undoRedo.redo(state); if (n != null) { state = n; return true; } return false; }
  void setProjectName(String name) { _undoRedo.recordSnapshot(state); state = state.copyWith(name: name); }

  void addImages(List<String> paths, {String trackId = 'track_v1', int? insertAtMs}) {
    if (paths.isEmpty) return;
    _undoRedo.recordSnapshot(state);

    final trackClips = state.images.where((i) => i.trackId == trackId).toList()
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    final otherClips = state.images.where((i) => i.trackId != trackId).toList();

    List<ImageItem> combinedTrack;
    if (insertAtMs == null) {
      final items = paths.map((path) => ImageItem(
        id: _uuid.v4(), filePath: path, displayName: p.basename(path),
        orderIndex: trackClips.length, trackId: trackId,
      )).toList();
      combinedTrack = [...trackClips, ...items];
    } else {
      final clampedAt = insertAtMs.clamp(0, 36000000);
      const defaultDur = TimingEngine.defaultImageDurationMs;
      final newItems = <ImageItem>[];
      int cursorMs = clampedAt;
      for (int i = 0; i < paths.length; i++) {
        final path = paths[i];
        newItems.add(ImageItem(
          id: _uuid.v4(),
          filePath: path,
          displayName: p.basename(path),
          orderIndex: 0,
          trackId: trackId,
          startMs: cursorMs,
          endMs: cursorMs + defaultDur,
          durationMs: defaultDur,
          userStartTimestampInput: (cursorMs / 1000.0).toStringAsFixed(2),
          userEndTimestampInput: ((cursorMs + defaultDur) / 1000.0).toStringAsFixed(2),
        ));
        cursorMs += defaultDur;
      }

      final totalAddedDur = newItems.length * defaultDur;
      final adjustedExisting = <ImageItem>[];
      for (final existing in trackClips) {
        if (existing.endMs <= clampedAt) {
          // Before insertion point: keep exact position
          adjustedExisting.add(existing.copyWith(
            userStartTimestampInput: existing.userStartTimestampInput ?? (existing.startMs / 1000.0).toStringAsFixed(2),
            userEndTimestampInput: existing.userEndTimestampInput ?? (existing.endMs / 1000.0).toStringAsFixed(2),
          ));
        } else if (existing.startMs >= clampedAt + totalAddedDur) {
          // After inserted items with enough blank space: keep exact position
          adjustedExisting.add(existing.copyWith(
            userStartTimestampInput: existing.userStartTimestampInput ?? (existing.startMs / 1000.0).toStringAsFixed(2),
            userEndTimestampInput: existing.userEndTimestampInput ?? (existing.endMs / 1000.0).toStringAsFixed(2),
          ));
        } else {
          // Overlaps insertion range: shift right so inserted asset fits cleanly at playhead
          final shift = (clampedAt + totalAddedDur) - existing.startMs;
          final ns = existing.startMs + shift;
          final ne = existing.endMs + shift;
          adjustedExisting.add(existing.copyWith(
            startMs: ns,
            endMs: ne,
            userStartTimestampInput: (ns / 1000.0).toStringAsFixed(2),
            userEndTimestampInput: (ne / 1000.0).toStringAsFixed(2),
          ));
        }
      }

      combinedTrack = [...adjustedExisting, ...newItems]
        ..sort((a, b) => a.startMs.compareTo(b.startMs));
    }

    final items = combinedTrack.where((i) => paths.contains(i.filePath)).toList();
    state = state.copyWith(
      images: TimingEngine.calculateSequence(
        images: [...otherClips, ...combinedTrack],
        voiceOverDurationMs: state.voiceOver?.durationMs,
        snapFinalImageToAudio: insertAtMs == null && state.timingMode == TimingMode.automatic,
      ),
    );

    for (final item in items) {
      if (item.isVideo) {
        VideoMetadataService.resolveDuration(item.filePath).then((durMs) {
          if (durMs > 0) {
            final current = state.images.where((img) => img.id == item.id).firstOrNull;
            if (current != null) {
              final withSource = state.images.map((img) => img.id == item.id ? img.copyWith(sourceDurationMs: durMs) : img).toList();
              state = state.copyWith(images: withSource);
              final newEnd = current.startMs + durMs;
              updateTimestamp(item.id, (newEnd / 1000).toStringAsFixed(2), recordUndo: false);
            }
          }
        });
        VideoMetadataService.getThumbnailPath(item.filePath);
        VideoMetadataService.getAudioTrackPath(item.filePath);
      }
    }
  }

  void addColorBackground({Color color = const Color(0xFF1E293B), int durationMs = 3000, int? targetIndex, String trackId = 'track_v1', int? insertAtMs}) {
    _undoRedo.recordSnapshot(state);
    if (insertAtMs != null) {
      final clampedAt = insertAtMs.clamp(0, 36000000);
      final item = ImageItem(
        id: _uuid.v4(), filePath: 'color_background', displayName: 'Color BG',
        orderIndex: 0, startMs: clampedAt, endMs: clampedAt + durationMs, durationMs: durationMs,
        userStartTimestampInput: (clampedAt / 1000.0).toStringAsFixed(2),
        userEndTimestampInput: ((clampedAt + durationMs) / 1000.0).toStringAsFixed(2),
        backgroundColorValue: color.toARGB32(), trackId: trackId,
      );
      final trackClips = state.images.where((i) => i.trackId == trackId).toList()
        ..add(item)
        ..sort((a, b) => a.startMs.compareTo(b.startMs));
      final otherClips = state.images.where((i) => i.trackId != trackId).toList();
      state = state.copyWith(images: TimingEngine.calculateSequence(images: [...otherClips, ...trackClips], voiceOverDurationMs: state.voiceOver?.durationMs, snapFinalImageToAudio: false));
      return;
    }
    final idx = (targetIndex ?? state.images.length).clamp(0, state.images.length);
    final item = ImageItem(
      id: _uuid.v4(), filePath: 'color_background', displayName: 'Color BG',
      orderIndex: idx, durationMs: durationMs, backgroundColorValue: color.toARGB32(), trackId: trackId,
    );
    final updated = List<ImageItem>.from(state.images)..insert(idx, item);
    for (int i = 0; i < updated.length; i++) { updated[i] = updated[i].copyWith(orderIndex: i); }
    state = state.copyWith(images: TimingEngine.calculateSequence(images: updated, voiceOverDurationMs: state.voiceOver?.durationMs));
  }

  void updateImageColor(String imageId, Color color, {bool recordUndo = true}) {
    if (recordUndo) _undoRedo.recordSnapshot(state);
    final updated = state.images.map((img) => img.id == imageId ? img.copyWith(backgroundColorValue: color.toARGB32()) : img).toList();
    state = state.copyWith(images: updated);
  }

  void insertImagesAt(int targetIndex, List<String> paths, {String trackId = 'track_v1'}) {
    if (paths.isEmpty) return;
    _undoRedo.recordSnapshot(state);
    final idx = targetIndex.clamp(0, state.images.length);
    final items = paths.map((path) => ImageItem(id: _uuid.v4(), filePath: path, displayName: p.basename(path), orderIndex: idx, trackId: trackId)).toList();
    final updated = List<ImageItem>.from(state.images)..insertAll(idx, items);
    for (int i = 0; i < updated.length; i++) { updated[i] = updated[i].copyWith(orderIndex: i); }
    state = state.copyWith(images: TimingEngine.calculateSequence(images: updated, voiceOverDurationMs: state.voiceOver?.durationMs));

    for (final item in items) {
      if (item.isVideo) {
        VideoMetadataService.resolveDuration(item.filePath).then((durMs) {
          if (durMs > 0) {
            final current = state.images.where((img) => img.id == item.id).firstOrNull;
            if (current != null) {
              final withSource = state.images.map((img) => img.id == item.id ? img.copyWith(sourceDurationMs: durMs) : img).toList();
              state = state.copyWith(images: withSource);
              final newEnd = current.startMs + durMs;
              updateTimestamp(item.id, (newEnd / 1000).toStringAsFixed(2), recordUndo: false);
            }
          }
        });
        VideoMetadataService.getThumbnailPath(item.filePath);
        VideoMetadataService.getAudioTrackPath(item.filePath);
      }
    }
  }

  void trimClipEnd(String imageId, int newEndMs, {bool recordUndo = true}) {
    if (recordUndo) _undoRedo.recordSnapshot(state);
    final updatedImages = ClipEditingService.rippleTrimClipEnd(images: state.images, clipId: imageId, newEndMs: newEndMs, voiceOverDurationMs: state.voiceOver?.durationMs);
    state = state.copyWith(
      images: updatedImages,
      explicitGaps: _reconcileGapsWithClips(state.explicitGaps, updatedImages),
    );
  }

  void trimClipStart(String imageId, int newStartMs, {bool recordUndo = true}) {
    if (recordUndo) _undoRedo.recordSnapshot(state);
    final updatedImages = ClipEditingService.trimClipStart(images: state.images, clipId: imageId, newStartMs: newStartMs, voiceOverDurationMs: state.voiceOver?.durationMs);
    state = state.copyWith(
      images: updatedImages,
      explicitGaps: _reconcileGapsWithClips(state.explicitGaps, updatedImages),
    );
  }

  void snapClipToAudio(String imageId) { if (state.voiceOver != null) trimClipEnd(imageId, state.voiceOver!.durationMs); }
  void removeImage(String id, {bool preserveGap = true}) {
    if (preserveGap) {
      removeClipsPreservingGaps({id});
      return;
    }
    _undoRedo.recordSnapshot(state);
    final updated = TimingEngine.calculateSequence(images: state.images.where((img) => img.id != id).toList(), voiceOverDurationMs: state.voiceOver?.durationMs);
    state = _pruneEmptySecondaryTracks(state.copyWith(images: updated));
  }

  void removeClipsPreservingGaps(Set<String> clipIds) {
    if (clipIds.isEmpty) return;
    _undoRedo.recordSnapshot(state);
    final updated = ClipEditingService.deleteClipPreservingGaps(
      images: state.images,
      clipIdsToDelete: clipIds,
      voiceOverDurationMs: state.voiceOver?.durationMs,
    );
    state = _pruneEmptySecondaryTracks(state.copyWith(
      images: updated,
    ));
  }

  /// Explicitly creates a blank space of [durationMs] at [startMs] on [trackId].
  void createBlankAtPlayhead(String trackId, int startMs, {int durationMs = 3000}) {
    _undoRedo.recordSnapshot(state);
    final clampedStart = startMs.clamp(0, 36000000);
    final dur = durationMs.clamp(200, 3600000);

    final shiftedImages = state.images.map((img) {
      if (img.trackId == trackId && img.startMs >= clampedStart) {
        final ns = img.startMs + dur;
        final ne = img.endMs + dur;
        return img.copyWith(
          userStartTimestampInput: (ns / 1000.0).toStringAsFixed(2),
          userEndTimestampInput: (ne / 1000.0).toStringAsFixed(2),
        );
      }
      return img;
    }).toList();

    final calculated = TimingEngine.calculateSequence(
      images: shiftedImages,
      voiceOverDurationMs: state.voiceOver?.durationMs,
      snapFinalImageToAudio: false,
    );
    final gap = TimelineGap(
      id: _uuid.v4(),
      trackId: trackId,
      startMs: clampedStart,
      endMs: clampedStart + dur,
    );
    state = state.copyWith(
      images: calculated,
      explicitGaps: [...state.explicitGaps, gap],
    );
  }

  /// Deletes an explicit blank space (optionally rippling subsequent clips left).
  void removeExplicitGap(String gapId, {bool ripple = true}) {
    final gap = state.explicitGaps.where((g) => g.id == gapId).firstOrNull;
    if (gap == null) return;
    _undoRedo.recordSnapshot(state);
    final remainingGaps = state.explicitGaps.where((g) => g.id != gapId).toList();
    if (!ripple) {
      state = state.copyWith(explicitGaps: remainingGaps);
      return;
    }
    final dur = gap.durationMs;
    final shiftedImages = state.images.map((img) {
      if (img.trackId == gap.trackId && img.startMs >= gap.endMs) {
        final ns = (img.startMs - dur).clamp(0, 36000000);
        final ne = (img.endMs - dur).clamp(ns + 200, 36000000);
        return img.copyWith(
          userStartTimestampInput: (ns / 1000.0).toStringAsFixed(2),
          userEndTimestampInput: (ne / 1000.0).toStringAsFixed(2),
        );
      }
      return img;
    }).toList();
    state = state.copyWith(
      images: TimingEngine.calculateSequence(
        images: shiftedImages,
        voiceOverDurationMs: state.voiceOver?.durationMs,
        snapFinalImageToAudio: false,
      ),
      explicitGaps: remainingGaps,
    );
  }

  /// Shrinks or removes explicit gaps that are now covered by clips.
  List<TimelineGap> _reconcileGapsWithClips(List<TimelineGap> gaps, List<ImageItem> images) {
    if (gaps.isEmpty) return const [];
    final result = <TimelineGap>[];
    for (final gap in gaps) {
      int gStart = gap.startMs;
      int gEnd = gap.endMs;
      final trackClips = images.where((i) => i.trackId == gap.trackId).toList();
      bool fullyCovered = false;
      for (final c in trackClips) {
        if (c.startMs <= gStart && c.endMs >= gEnd) {
          fullyCovered = true;
          break;
        }
        if (c.startMs <= gStart && c.endMs > gStart && c.endMs < gEnd) {
          gStart = c.endMs;
        }
        if (c.startMs > gStart && c.startMs < gEnd && c.endMs >= gEnd) {
          gEnd = c.startMs;
        }
      }
      if (!fullyCovered && gEnd - gStart > 100) {
        result.add(gap.copyWith(startMs: gStart, endMs: gEnd));
      }
    }
    return result;
  }

  Project _pruneEmptySecondaryTracks(Project p) {
    if (p.tracks.isEmpty) return p;
    final remaining = p.tracks.where((t) {
      if (t.type == TrackType.mainVideo || t.id == 'track_v1') return true;
      if (t.type == TrackType.audio) return p.audioClips.isNotEmpty || p.voiceOver != null;
      if (t.type == TrackType.text) return p.textOverlays.isNotEmpty;
      return p.images.any((img) => img.trackId == t.id);
    }).toList();
    return remaining.length == p.tracks.length ? p : p.copyWith(tracks: remaining);
  }

  void applyAlignment({required Set<String> targetIds, required AlignmentType type}) {
    if (targetIds.isEmpty) return;
    _undoRedo.recordSnapshot(state);
    state = state.copyWith(
      images: AlignmentService.alignMultiple(
        allImages: state.images,
        targetIds: targetIds,
        type: type,
      ),
    );
  }
  void reorderImages(int oldIndex, int newIndex) {
    _undoRedo.recordSnapshot(state);
    final list = List<ImageItem>.from(state.images);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex > oldIndex ? newIndex - 1 : newIndex, item);
    state = state.copyWith(images: TimingEngine.calculateSequence(images: list, voiceOverDurationMs: state.voiceOver?.durationMs));
  }

  void moveImageClipStart(String clipId, int newStartMs) { _undoRedo.recordSnapshot(state); state = state.copyWith(images: TimelineArrangementService.moveClipStart(images: state.images, clipId: clipId, newStartMs: newStartMs, voiceOverDurationMs: state.voiceOver?.durationMs)); }

  /// Places a dropped clip onto [targetTrackId] at [startMs] while strictly preserving its duration.
  void placeClipOnTrack({
    required ImageItem clip,
    required String targetTrackId,
    required int startMs,
  }) {
    _undoRedo.recordSnapshot(state);
    final dur = clip.durationMs > 0 ? clip.durationMs : TimingEngine.defaultImageDurationMs;
    final clampedStart = startMs.clamp(0, 36000000);
    final endMs = clampedStart + dur;

    final existingIdx = state.images.indexWhere((i) => i.id == clip.id);
    final bool isSameTrack = existingIdx >= 0 && state.images[existingIdx].trackId == targetTrackId;

    final newOrMoved = clip.copyWith(
      id: (existingIdx >= 0 && !isSameTrack) ? _uuid.v4() : clip.id,
      trackId: targetTrackId,
      startMs: clampedStart,
      endMs: endMs,
      durationMs: dur,
      userStartTimestampInput: (clampedStart / 1000.0).toStringAsFixed(2),
      userEndTimestampInput: (endMs / 1000.0).toStringAsFixed(2),
      clearValidationError: true,
    );

    final updated = <ImageItem>[];
    int pushCursor = endMs;
    final othersOnTrack = <ImageItem>[];
    for (int i = 0; i < state.images.length; i++) {
      final img = state.images[i];
      if (isSameTrack && i == existingIdx) continue;
      if (img.trackId == targetTrackId) {
        othersOnTrack.add(img);
      } else {
        updated.add(img);
      }
    }
    othersOnTrack.sort((a, b) => a.startMs.compareTo(b.startMs));

    for (final img in othersOnTrack) {
      if (img.endMs <= clampedStart) {
        // Before dropped clip: keep exact position
        updated.add(img.copyWith(
          userStartTimestampInput: img.userStartTimestampInput ?? (img.startMs / 1000.0).toStringAsFixed(2),
          userEndTimestampInput: img.userEndTimestampInput ?? (img.endMs / 1000.0).toStringAsFixed(2),
        ));
      } else if (img.startMs >= pushCursor) {
        // After dropped clip without overlap: keep exact position
        updated.add(img.copyWith(
          userStartTimestampInput: img.userStartTimestampInput ?? (img.startMs / 1000.0).toStringAsFixed(2),
          userEndTimestampInput: img.userEndTimestampInput ?? (img.endMs / 1000.0).toStringAsFixed(2),
        ));
        pushCursor = img.endMs;
      } else {
        // Overlaps dropped clip: shift right so dropped clip stays exactly where user stopped
        final imgDur = img.durationMs > 0 ? img.durationMs : TimingEngine.defaultImageDurationMs;
        final ns = pushCursor;
        final ne = ns + imgDur;
        updated.add(img.copyWith(
          startMs: ns,
          endMs: ne,
          userStartTimestampInput: (ns / 1000.0).toStringAsFixed(2),
          userEndTimestampInput: (ne / 1000.0).toStringAsFixed(2),
        ));
        pushCursor = ne;
      }
    }
    updated.add(newOrMoved);
    updated.sort((a, b) {
      if (a.trackId != b.trackId) return a.trackId.compareTo(b.trackId);
      return a.startMs.compareTo(b.startMs);
    });

    final calculated = TimingEngine.calculateSequence(
      images: updated,
      voiceOverDurationMs: state.voiceOver?.durationMs,
      snapFinalImageToAudio: false,
    );
    state = state.copyWith(
      images: calculated,
      explicitGaps: _reconcileGapsWithClips(state.explicitGaps, calculated),
    );
  }
  void swapImageClips(String idA, String idB) { _undoRedo.recordSnapshot(state); state = state.copyWith(images: TimelineArrangementService.swapClips(images: state.images, idA: idA, idB: idB, voiceOverDurationMs: state.voiceOver?.durationMs)); }
  void reorderAndOccupy(String draggedId, String targetId, {required bool insertBefore}) { _undoRedo.recordSnapshot(state); state = state.copyWith(images: TimelineArrangementService.reorderAndOccupy(images: state.images, draggedId: draggedId, targetId: targetId, insertBefore: insertBefore, voiceOverDurationMs: state.voiceOver?.durationMs)); }
  void fillBlankGap({required int startMs, required int endMs, required String trackId, required bool isColorBg, String? imagePath, Color? color, String? existingClipId}) {
    _undoRedo.recordSnapshot(state);
    final List<ImageItem> nextImages;
    if (existingClipId != null) {
      nextImages = TimelineArrangementService.fillGapWithClip(images: state.images, clipId: existingClipId, startMs: startMs, gapEndMs: endMs, targetTrackId: trackId, voiceOverDurationMs: state.voiceOver?.durationMs);
    } else {
      nextImages = TimelineArrangementService.fillGap(images: state.images, startMs: startMs, endMs: endMs, trackId: trackId, isColorBg: isColorBg, imagePath: imagePath, color: color, voiceOverDurationMs: state.voiceOver?.durationMs);
    }
    state = state.copyWith(
      images: nextImages,
      explicitGaps: _reconcileGapsWithClips(state.explicitGaps, nextImages),
    );
  }
  void insertAssetAfterClip({required ImageItem afterClip, required bool isColorBg, String? imagePath, Color? color}) {
    _undoRedo.recordSnapshot(state);
    state = state.copyWith(
      images: TimelineArrangementService.insertAfterClip(
        images: state.images,
        afterClip: afterClip,
        isColorBg: isColorBg,
        imagePath: imagePath,
        color: color,
        voiceOverDurationMs: state.voiceOver?.durationMs,
      ),
    );
    if (imagePath != null) {
      final matches = state.images.where((i) => i.filePath == imagePath).toList();
      if (matches.isNotEmpty && matches.last.isVideo) {
        final inserted = matches.last;
        VideoMetadataService.resolveDuration(imagePath).then((durMs) {
          if (durMs > 0) {
            final current = state.images.where((img) => img.id == inserted.id).firstOrNull;
            if (current != null) {
              final withSource = state.images.map((img) => img.id == inserted.id ? img.copyWith(sourceDurationMs: durMs) : img).toList();
              state = state.copyWith(images: withSource);
              final newEnd = current.startMs + durMs;
              updateTimestamp(inserted.id, (newEnd / 1000).toStringAsFixed(2), recordUndo: false);
            }
          }
        });
        VideoMetadataService.getThumbnailPath(imagePath);
        VideoMetadataService.getAudioTrackPath(imagePath);
      }
    }
  }

  void updateTimestamp(String imageId, String? timestampInput, {bool recordUndo = true}) {
    if (recordUndo) _undoRedo.recordSnapshot(state);
    state = state.copyWith(images: TimingEngine.updateImageTimestamp(images: state.images, imageId: imageId, newTimestampInput: timestampInput, voiceOverDurationMs: state.voiceOver?.durationMs));
  }

  /// Sets a specific source range [sourceStartMs..sourceEndMs] for a video clip
  /// (e.g., 5min to 8min out of a 10min video -> 3min timeline clip).
  void updateVideoSourceRange(String clipId, int sourceStartMs, int sourceEndMs) {
    final idx = state.images.indexWhere((img) => img.id == clipId);
    if (idx < 0) return;
    final clip = state.images[idx];
    final clampedStart = sourceStartMs.clamp(0, (clip.sourceDurationMs ?? sourceEndMs) - 200);
    final clampedEnd = sourceEndMs.clamp(clampedStart + 200, clip.sourceDurationMs ?? sourceEndMs);
    final newDurationMs = clampedEnd - clampedStart;

    _undoRedo.recordSnapshot(state);
    final newEndTimelineMs = clip.startMs + newDurationMs;
    final updated = List<ImageItem>.from(state.images);
    updated[idx] = clip.copyWith(
      sourceStartOffsetMs: clampedStart,
      userStartTimestampInput: clip.userStartTimestampInput ?? (clip.startMs / 1000.0).toStringAsFixed(2),
      userEndTimestampInput: (newEndTimelineMs / 1000.0).toStringAsFixed(2),
    );
    state = state.copyWith(
      images: TimingEngine.calculateSequence(
        images: updated,
        voiceOverDurationMs: state.voiceOver?.durationMs,
        snapFinalImageToAudio: false,
      ),
    );
  }

  void autoArrangeFromLeft({String? trackId}) {
    _undoRedo.recordSnapshot(state);
    state = state.copyWith(
      images: TimelineArrangementService.autoArrangeFromLeft(
        images: state.images,
        trackId: trackId,
        voiceOverDurationMs: state.voiceOver?.durationMs,
      ),
      explicitGaps: trackId == null
          ? const []
          : state.explicitGaps.where((g) => g.trackId != trackId).toList(),
    );
  }

  void toggleAssetMark(String id) {
    _undoRedo.recordSnapshot(state);
    if (state.images.any((i) => i.id == id)) {
      state = state.copyWith(
        images: state.images.map((i) => i.id == id ? i.copyWith(isMarked: !i.isMarked) : i).toList(),
      );
      return;
    }
    if (state.textOverlays.any((t) => t.id == id)) {
      state = state.copyWith(
        textOverlays: state.textOverlays.map((t) => t.id == id ? t.copyWith(isMarked: !t.isMarked) : t).toList(),
      );
      return;
    }
    final clips = state.audioClips.isNotEmpty ? state.audioClips : state.effectiveAudioClips;
    if (clips.any((a) => a.id == id)) {
      state = state.copyWith(
        audioClips: clips.map((a) => a.id == id ? a.copyWith(isMarked: !a.isMarked) : a).toList(),
      );
    }
  }

  void addMarker(int timestampMs, {String label = 'Marker', int colorValue = 0xFFFF5C36}) {
    _undoRedo.recordSnapshot(state);
    final m = TimelineMarker(
      id: _uuid.v4(),
      timestampMs: timestampMs.clamp(0, 36000000),
      label: label,
      colorValue: colorValue,
    );
    final updated = [...state.markers, m]..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    state = state.copyWith(markers: updated);
  }

  void removeMarker(String markerId) {
    _undoRedo.recordSnapshot(state);
    state = state.copyWith(markers: state.markers.where((m) => m.id != markerId).toList());
  }

  void renameMarker(String markerId, String newLabel) {
    _undoRedo.recordSnapshot(state);
    state = state.copyWith(
      markers: state.markers.map((m) => m.id == markerId ? m.copyWith(label: newLabel) : m).toList(),
    );
  }
  void updateStartTimestamp(String imageId, String? startInput) { _undoRedo.recordSnapshot(state); state = state.copyWith(images: TimingEngine.updateImageStartTimestamp(images: state.images, imageId: imageId, newStartInput: startInput, voiceOverDurationMs: state.voiceOver?.durationMs)); }
  void applyBulkTimestamps(List<String> timestampList, {String? trackId}) { _undoRedo.recordSnapshot(state); state = state.copyWith(images: TimingEngine.applyBulkTimestamps(images: state.images, timestampList: timestampList, voiceOverDurationMs: state.voiceOver?.durationMs, trackId: trackId)); }

  String? stampCurrentCutPoint(int currentMs) {
    if (state.images.isEmpty) return null;
    final idx = TimingEngine.findActiveImageIndex(state.images, currentMs);
    if (idx < 0 || idx >= state.images.length || currentMs <= state.images[idx].startMs) return null;
    updateTimestamp(state.images[idx].id, (currentMs / 1000).toStringAsFixed(2));
    return state.images[idx].displayName;
  }

  bool splitAtPlayhead(int playheadMs) {
    final res = ClipEditingService.splitClipAt(images: state.images, playheadMs: playheadMs, voiceOverDurationMs: state.voiceOver?.durationMs);
    if (res == null) return false;
    _undoRedo.recordSnapshot(state);
    state = state.copyWith(images: res);
    return true;
  }

  void duplicateImage(String imageId) { _undoRedo.recordSnapshot(state); state = state.copyWith(images: ClipEditingService.duplicateClip(images: state.images, clipId: imageId, voiceOverDurationMs: state.voiceOver?.durationMs)); }
  void updateFitMode(String imageId, ImageFitMode mode) { _undoRedo.recordSnapshot(state); state = state.copyWith(images: state.images.map((img) => img.id == imageId ? img.copyWith(fitMode: mode) : img).toList()); }

  void setVoiceOver(VoiceOver voiceOver) {
    _undoRedo.recordSnapshot(state);
    final clip = AudioClipItem(id: _uuid.v4(), filePath: voiceOver.filePath, fileName: voiceOver.fileName, startTimelineMs: 0, durationMs: voiceOver.durationMs, orderIndex: 0);
    final snap = state.timingMode == TimingMode.automatic;
    state = state.copyWith(voiceOver: voiceOver, audioClips: [clip], images: TimingEngine.calculateSequence(images: state.images, voiceOverDurationMs: voiceOver.durationMs, snapFinalImageToAudio: snap));
  }

  void addAudioClip(String filePath, String fileName, int durationMs, {int? customStartMs}) {
    _undoRedo.recordSnapshot(state);
    var cur = state.audioClips;
    if (cur.isEmpty && state.voiceOver != null) {
      cur = [AudioClipItem(id: _uuid.v4(), filePath: state.voiceOver!.filePath, fileName: state.voiceOver!.fileName, startTimelineMs: 0, durationMs: state.voiceOver!.durationMs, orderIndex: 0)];
    }
    final updated = AudioEditingService.appendAudioClip(existingClips: cur, filePath: filePath, fileName: fileName, durationMs: durationMs, customStartMs: customStartMs);
    state = state.copyWith(audioClips: updated, voiceOver: updated.isNotEmpty ? VoiceOver(filePath: updated.first.filePath, fileName: updated.first.fileName, durationMs: updated.fold<int>(0, (s, c) => s + c.durationMs)) : null);
  }

  void moveAudioClipStart(String clipId, int newStartMs, {bool recordUndo = true}) {
    if (recordUndo) _undoRedo.recordSnapshot(state);
    final clips = state.audioClips.isNotEmpty ? state.audioClips : state.effectiveAudioClips;
    state = state.copyWith(audioClips: AudioEditingService.moveClipStart(clips: clips, clipId: clipId, newStartMs: newStartMs));
  }

  void applyAudioBulkTimestamps(List<String> timestampList) {
    if (timestampList.isEmpty) return;
    _undoRedo.recordSnapshot(state);
    final clips = List<AudioClipItem>.from(state.effectiveAudioClips);
    if (clips.isEmpty) return;

    final updated = <AudioClipItem>[];
    for (int i = 0; i < clips.length; i++) {
      final clip = clips[i];
      if (i < timestampList.length) {
        final stampText = timestampList[i];
        final range = CsvService.splitRange(stampText);
        final startMs = range != null
            ? (TimeParser.parseToMs(range[0]) ?? clip.startTimelineMs)
            : (TimeParser.parseToMs(stampText) ?? clip.startTimelineMs);
        updated.add(clip.copyWith(startTimelineMs: startMs));
      } else {
        updated.add(clip);
      }
    }

    updated.sort((a, b) => a.startTimelineMs.compareTo(b.startTimelineMs));
    final reindexed = <AudioClipItem>[];
    for (int i = 0; i < updated.length; i++) {
      reindexed.add(updated[i].copyWith(orderIndex: i));
    }
    state = state.copyWith(audioClips: reindexed);
  }

  void trimAudioClipEnd(String clipId, int newDurationMs, {bool recordUndo = true}) {
    if (recordUndo) _undoRedo.recordSnapshot(state);
    final clips = state.audioClips.isNotEmpty ? state.audioClips : state.effectiveAudioClips;
    final res = AudioEditingService.trimClipEnd(clips: clips, clipId: clipId, newDurationMs: newDurationMs);
    state = state.copyWith(audioClips: res);
  }

  void trimAudioClipStart(String clipId, int newStartTimelineMs, {bool recordUndo = true}) {
    if (recordUndo) _undoRedo.recordSnapshot(state);
    final clips = state.audioClips.isNotEmpty ? state.audioClips : state.effectiveAudioClips;
    final res = AudioEditingService.trimClipStart(clips: clips, clipId: clipId, newStartTimelineMs: newStartTimelineMs);
    state = state.copyWith(audioClips: res);
  }

  bool splitAudioAtPlayhead(int playheadMs) {
    final clips = state.audioClips.isNotEmpty ? state.audioClips : state.effectiveAudioClips;
    final res = AudioEditingService.splitAudioClipAt(clips: clips, playheadMs: playheadMs);
    if (res != null) {
      _undoRedo.recordSnapshot(state);
      state = state.copyWith(audioClips: res);
      return true;
    }
    return false;
  }

  bool splitSpecificAudioClip(String clipId, {int? atTimelineMs}) {
    final clips = state.audioClips.isNotEmpty ? state.audioClips : state.effectiveAudioClips;
    final res = AudioEditingService.splitSpecificClip(clips: clips, clipId: clipId, splitTimelineMs: atTimelineMs);
    if (res != null) {
      _undoRedo.recordSnapshot(state);
      state = state.copyWith(audioClips: res);
      return true;
    }
    return false;
  }

  bool smartSplitAtPlayhead(int playheadMs, {String? selectedAudioId}) {
    if (selectedAudioId != null) {
      final audioOk = splitAudioAtPlayhead(playheadMs);
      if (audioOk) return true;
    }
    final imageOk = splitAtPlayhead(playheadMs);
    if (imageOk) return true;
    final audioOk = splitAudioAtPlayhead(playheadMs);
    if (audioOk) return true;
    return false;
  }

  void deleteAudioClip(String clipId) {
    _undoRedo.recordSnapshot(state);
    final clips = state.audioClips.isNotEmpty ? state.audioClips : state.effectiveAudioClips;
    final res = AudioEditingService.deleteAudioClip(clips: clips, clipId: clipId);
    state = state.copyWith(
      audioClips: res,
      voiceOver: res.isNotEmpty ? VoiceOver(filePath: res.first.filePath, fileName: res.first.fileName, durationMs: res.fold<int>(0, (s, c) => s + c.durationMs)) : null,
      clearVoiceOver: res.isEmpty,
    );
  }

  void setAudioClipVolume(String clipId, double volume) {
    _undoRedo.recordSnapshot(state);
    final clips = state.audioClips.isNotEmpty ? state.audioClips : state.effectiveAudioClips;
    state = state.copyWith(audioClips: AudioEditingService.updateVolume(clips: clips, clipId: clipId, volume: volume));
  }

  void trimAudioClip(String clipId, int newDurationMs) => trimAudioClipEnd(clipId, newDurationMs);
  void removeVoiceOver() { _undoRedo.recordSnapshot(state); state = state.copyWith(clearVoiceOver: true, images: TimingEngine.calculateSequence(images: state.images, voiceOverDurationMs: null, snapFinalImageToAudio: false)); }
  void toggleTimingMode() { _undoRedo.recordSnapshot(state); state = state.copyWith(timingMode: state.timingMode == TimingMode.automatic ? TimingMode.manual : TimingMode.automatic); }

  void toggleTrackVisibility(String trackId) {
    _undoRedo.recordSnapshot(state);
    final updated = state.effectiveTracks.map((t) => t.id == trackId ? t.copyWith(isVisible: !t.isVisible) : t).toList();
    state = state.copyWith(tracks: updated);
  }

  void toggleTrackMute(String trackId) {
    _undoRedo.recordSnapshot(state);
    final updated = state.effectiveTracks.map((t) => t.id == trackId ? t.copyWith(isMuted: !t.isMuted) : t).toList();
    state = state.copyWith(tracks: updated);
  }

  void toggleImageMute(String imageId) {
    _undoRedo.recordSnapshot(state);
    final updated = state.images.map((img) => img.id == imageId ? img.copyWith(isMuted: !img.isMuted) : img).toList();
    state = state.copyWith(images: updated);
  }

  void addTrack({required String name, required TrackType type}) {
    _undoRedo.recordSnapshot(state);
    final current = state.effectiveTracks;
    state = state.copyWith(tracks: [...current, TimelineTrackItem(id: 'track_${_uuid.v4().substring(0, 8)}', name: name, type: type, orderIndex: current.length)]);
  }

  void removeTrack(String trackId) {
    _undoRedo.recordSnapshot(state);
    final target = state.effectiveTracks.where((t) => t.id == trackId).firstOrNull;
    final isMainTrack = target?.type == TrackType.mainVideo || trackId == 'track_v1';
    final updatedTracks = isMainTrack
        ? state.effectiveTracks
        : state.effectiveTracks.where((t) => t.id != trackId).toList();
    final isAudio = target?.type == TrackType.audio;
    final isText = target?.type == TrackType.text;
    state = state.copyWith(
      tracks: updatedTracks,
      images: state.images.where((i) => i.trackId != trackId).toList(),
      audioClips: isAudio ? const [] : state.audioClips,
      clearVoiceOver: isAudio,
      textOverlays: isText ? const [] : state.textOverlays,
    );
  }

  void recordSnapshot() => _undoRedo.recordSnapshot(state);
  void addTextOverlay(TextOverlayItem item) { _undoRedo.recordSnapshot(state); state = state.copyWith(textOverlays: TextEditingService.addOverlay(state.textOverlays, item)); }
  void updateTextOverlay(TextOverlayItem item, {bool recordUndo = true}) { if (recordUndo) _undoRedo.recordSnapshot(state); state = state.copyWith(textOverlays: TextEditingService.updateOverlay(state.textOverlays, item)); }
  void deleteTextOverlay(String id) { _undoRedo.recordSnapshot(state); state = _pruneEmptySecondaryTracks(state.copyWith(textOverlays: TextEditingService.deleteOverlay(state.textOverlays, id))); }
  void trimTextOverlay(String id, {int? startMs, int? durationMs, bool recordUndo = true}) { if (recordUndo) _undoRedo.recordSnapshot(state); state = state.copyWith(textOverlays: TextEditingService.trimOverlay(state.textOverlays, id, startMs: startMs, durationMs: durationMs)); }

  void updateImageTransform(String imageId, AssetTransform t, {bool recordUndo = true}) { if (recordUndo) _undoRedo.recordSnapshot(state); state = AssetAnimationService.updateTransform(state, imageId, t); }
  void addImageAnimation(String imageId, AssetAnimation a) { _undoRedo.recordSnapshot(state); state = AssetAnimationService.addAnimation(state, imageId, a); }
  void removeImageAnimation(String imageId, String animId) { _undoRedo.recordSnapshot(state); state = AssetAnimationService.removeAnimation(state, imageId, animId); }
  void updateImageAnimation(String imageId, AssetAnimation a) { _undoRedo.recordSnapshot(state); state = AssetAnimationService.updateAnimation(state, imageId, a); }
  void clearImageAnimations(String imageId) { _undoRedo.recordSnapshot(state); state = AssetAnimationService.clearAnimations(state, imageId); }
  void applyAnimationRandomisation(List<ProposedAssignment> a, {int durationMs = 600}) { _undoRedo.recordSnapshot(state); state = AssetAnimationService.applyRandomisation(state, a, durationMs: durationMs); }

  void setAspectRatio(VideoAspectRatio r) => state = state.copyWith(aspectRatio: r);
  void setResolution(VideoResolution res) => state = state.copyWith(resolution: res);
  void newProject() { _undoRedo.clear(); state = Project(id: _uuid.v4(), name: 'Untitled Project'); }
  void loadProject(Project l) { _undoRedo.clear(); state = l; }
}

final projectProvider = StateNotifierProvider<ProjectNotifier, Project>((ref) => ProjectNotifier());
