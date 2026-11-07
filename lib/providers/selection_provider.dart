import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the ID of the currently selected ImageItem in the UI.
final selectedImageIdProvider = StateProvider<String?>((ref) => null);

/// Holds the current playhead position in milliseconds (0 to project total duration).
final playheadPositionProvider = StateProvider<int>((ref) => 0);

/// Tracks whether preview playback is currently playing.
final isPlayingProvider = StateProvider<bool>((ref) => false);

/// Tracks timeline horizontal zoom scale factor (1.0 = normal, 2.0 = zoomed in).
final timelineZoomProvider = StateProvider<double>((ref) => 1.0);
