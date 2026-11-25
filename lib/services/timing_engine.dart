import '../core/utils/time_parser.dart';
import '../models/image_item.dart';

class TimingEngine {
  static const int defaultImageDurationMs = 5000;

  static List<ImageItem> calculateSequence({
    required List<ImageItem> images,
    int? voiceOverDurationMs,
    bool snapFinalImageToAudio = true,
  }) {
    if (images.isEmpty) return const [];
    final trackIds = images.map((i) => i.trackId).toSet();
    if (trackIds.length > 1) {
      final res = <ImageItem>[];
      for (final tid in trackIds) {
        res.addAll(_calcTrack(images: images.where((i) => i.trackId == tid).toList(), voiceOverDurationMs: voiceOverDurationMs, snapFinalImageToAudio: snapFinalImageToAudio));
      }
      return res;
    }
    return _calcTrack(images: images, voiceOverDurationMs: voiceOverDurationMs, snapFinalImageToAudio: snapFinalImageToAudio);
  }

  static List<ImageItem> _calcTrack({required List<ImageItem> images, int? voiceOverDurationMs, bool snapFinalImageToAudio = true}) {
    if (images.isEmpty) return const [];
    final updated = <ImageItem>[];
    int currentTimelineMs = 0;

    for (int i = 0; i < images.length; i++) {
      final item = images[i];
      final isLast = (i == images.length - 1);
      String? validationError;
      int startMs = currentTimelineMs;

      final parsedUserStart = TimeParser.parseToMs(item.userStartTimestampInput);
      if (parsedUserStart != null) {
        if (parsedUserStart >= currentTimelineMs) {
          startMs = parsedUserStart;
        } else {
          validationError = 'Start time cannot overlap previous cut (${TimeParser.formatDetailed(currentTimelineMs)})';
        }
      }

      int endMs;
      final parsedUserEnd = TimeParser.parseToMs(item.userEndTimestampInput);
      if (isLast && snapFinalImageToAudio && voiceOverDurationMs != null && voiceOverDurationMs > 0 && voiceOverDurationMs > startMs) {
        endMs = voiceOverDurationMs;
      } else if (parsedUserEnd != null) {
        endMs = parsedUserEnd;
        if (endMs <= startMs) validationError = 'End time must be after start time (${TimeParser.formatDetailed(startMs)})';
      } else {
        if (isLast && snapFinalImageToAudio && voiceOverDurationMs != null && voiceOverDurationMs > startMs) {
          endMs = voiceOverDurationMs;
        } else {
          endMs = startMs + (item.durationMs > 0 ? item.durationMs : defaultImageDurationMs);
        }
      }

      final durationMs = endMs > startMs ? (endMs - startMs) : 0;
      updated.add(item.copyWith(
        orderIndex: i, startMs: startMs, endMs: endMs, durationMs: durationMs,
        validationError: validationError, clearValidationError: validationError == null,
      ));
      currentTimelineMs = endMs;
    }
    return updated;
  }

  static List<ImageItem> updateImageTimestamp({required List<ImageItem> images, required String imageId, required String? newTimestampInput, int? voiceOverDurationMs, bool snapFinalImageToAudio = true}) {
    final idx = images.indexWhere((img) => img.id == imageId);
    if (idx == -1) return images;
    final target = images[idx];
    final updated = List<ImageItem>.from(images);
    updated[idx] = target.copyWith(userEndTimestampInput: (newTimestampInput == null || newTimestampInput.trim().isEmpty) ? null : newTimestampInput.trim());
    return calculateSequence(images: updated, voiceOverDurationMs: voiceOverDurationMs, snapFinalImageToAudio: snapFinalImageToAudio);
  }

  static List<ImageItem> updateImageStartTimestamp({required List<ImageItem> images, required String imageId, required String? newStartInput, int? voiceOverDurationMs, bool snapFinalImageToAudio = true}) {
    final idx = images.indexWhere((img) => img.id == imageId);
    if (idx == -1) return images;
    final target = images[idx];
    final updated = List<ImageItem>.from(images);
    final trimmed = newStartInput?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      updated[idx] = target.copyWith(clearStartTimestamp: true);
    } else {
      updated[idx] = target.copyWith(userStartTimestampInput: trimmed);
    }
    return calculateSequence(images: updated, voiceOverDurationMs: voiceOverDurationMs, snapFinalImageToAudio: snapFinalImageToAudio);
  }

  static List<ImageItem> applyBulkTimestamps({
    required List<ImageItem> images,
    required List<String> timestampList,
    int? voiceOverDurationMs,
    bool snapFinalImageToAudio = true,
    String? trackId,
  }) {
    final modified = <ImageItem>[];
    int trackIdx = 0;
    for (int i = 0; i < images.length; i++) {
      final img = images[i];
      if (trackId != null && img.trackId != trackId) {
        modified.add(img);
        continue;
      }
      if (trackIdx < timestampList.length) {
        final raw = timestampList[trackIdx].trim();
        final rangeParts = _splitRange(raw);
        if (rangeParts != null && TimeParser.parseToMs(rangeParts[0]) != null && TimeParser.parseToMs(rangeParts[1]) != null) {
          modified.add(img.copyWith(userStartTimestampInput: rangeParts[0], userEndTimestampInput: rangeParts[1]));
        } else {
          modified.add(img.copyWith(clearStartTimestamp: true, userEndTimestampInput: raw));
        }
      } else {
        modified.add(img);
      }
      trackIdx++;
    }
    return calculateSequence(images: modified, voiceOverDurationMs: voiceOverDurationMs, snapFinalImageToAudio: snapFinalImageToAudio);
  }

  static List<String>? _splitRange(String text) {
    for (final sep in [' - ', ' – ', ' — ', ' to ', ' -> ']) {
      if (text.contains(sep)) {
        final p = text.split(sep);
        if (p.length == 2) return [p[0].trim(), p[1].trim()];
      }
    }
    if (text.contains('-')) {
      final p = text.split('-');
      if (p.length == 2 && p[0].contains(':') && p[1].contains(':')) return [p[0].trim(), p[1].trim()];
    }
    return null;
  }

  static int findActiveImageIndex(List<ImageItem> images, int playheadMs) {
    if (images.isEmpty) return -1;
    for (int i = 0; i < images.length; i++) {
      if (playheadMs >= images[i].startMs && playheadMs < images[i].endMs) return i;
    }
    return -1;
  }
}
