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
