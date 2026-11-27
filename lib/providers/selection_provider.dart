import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Workspace Focus Modes as specified in the PRD.
enum WorkspaceFocusMode {
  normal,
  timeline,
  preview,
  media,
}

/// Controls the active workspace layout mode.
final workspaceFocusModeProvider = StateProvider<WorkspaceFocusMode>((ref) => WorkspaceFocusMode.normal);

/// Controls user-customized timeline height in pixels (resizable vertically).
final timelineHeightProvider = StateProvider<double>((ref) => 300.0);

/// Holds the ID of the primary selected ImageItem in the UI.
final selectedImageIdProvider = StateProvider<String?>((ref) => null);

/// Holds the set of all currently selected clip IDs for multi-selection operations.
final selectedClipIdsProvider = StateProvider<Set<String>>((ref) => {});

/// Holds the ID of the currently selected AudioClipItem in the UI.
final selectedAudioClipIdProvider = StateProvider<String?>((ref) => null);

/// Holds the ID of the currently selected TextOverlayItem in the UI.
final selectedTextOverlayIdProvider = StateProvider<String?>((ref) => null);

/// Holds the current playhead position in milliseconds (0 to project total duration).
final playheadPositionProvider = StateProvider<int>((ref) => 0);

/// Tracks whether preview playback is currently playing.
final isPlayingProvider = StateProvider<bool>((ref) => false);

/// Tracks timeline horizontal zoom scale factor (1.0 = normal, 2.0 = zoomed in).
final timelineZoomProvider = StateProvider<double>((ref) => 1.0);

/// Tracks whether CapCut-style magnetic snapping is active on the timeline.
final snappingEnabledProvider = StateProvider<bool>((ref) => true);

/// Preview playback decoding quality (controls decode resolution & filter quality
/// for smooth playback on low-end PCs; never affects final FFmpeg export quality).
enum PreviewQuality {
  high('High', null, FilterQuality.high),
  standard('Standard', 1280, FilterQuality.medium),
  medium('Medium', 854, FilterQuality.low),
  low('Low', 640, FilterQuality.low),
  veryLow('Very Low', 360, FilterQuality.none);

  final String label;
  final int? cacheWidth;
  final FilterQuality filterQuality;
  const PreviewQuality(this.label, this.cacheWidth, this.filterQuality);
}

final previewQualityProvider = StateProvider<PreviewQuality>((ref) => PreviewQuality.standard);

/// Holds the active snap guide line position in milliseconds while dragging/trimming.
final activeSnapLineMsProvider = StateProvider<int?>((ref) => null);

/// Unified selection helpers so clicking any image, video, text, or audio
/// clears conflicting selections and immediately displays that asset's properties.
class SelectionHelper {
  static void selectImage(WidgetRef ref, String id) {
    ref.read(selectedAudioClipIdProvider.notifier).state = null;
    ref.read(selectedTextOverlayIdProvider.notifier).state = null;
    ref.read(selectedClipIdsProvider.notifier).state = {id};
    ref.read(selectedImageIdProvider.notifier).state = id;
  }

  static void selectTextOverlay(WidgetRef ref, String id) {
    ref.read(selectedAudioClipIdProvider.notifier).state = null;
    ref.read(selectedImageIdProvider.notifier).state = null;
    ref.read(selectedClipIdsProvider.notifier).state = {};
    ref.read(selectedTextOverlayIdProvider.notifier).state = id;
  }

  static void selectAudioClip(WidgetRef ref, String id) {
    ref.read(selectedImageIdProvider.notifier).state = null;
    ref.read(selectedClipIdsProvider.notifier).state = {};
    ref.read(selectedTextOverlayIdProvider.notifier).state = null;
    ref.read(selectedAudioClipIdProvider.notifier).state = id;
  }

  static void clearAll(WidgetRef ref) {
    ref.read(selectedImageIdProvider.notifier).state = null;
    ref.read(selectedClipIdsProvider.notifier).state = {};
    ref.read(selectedTextOverlayIdProvider.notifier).state = null;
    ref.read(selectedAudioClipIdProvider.notifier).state = null;
  }
}
