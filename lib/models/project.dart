import 'package:flutter/foundation.dart';
import 'image_item.dart';
import 'voice_over.dart';

/// Video Aspect Ratio options
enum VideoAspectRatio {
  ratio16x9('16:9', 16 / 9),
  ratio9x16('9:16 (Shorts/Reels)', 9 / 16),
  ratio1x1('1:1 (Square)', 1 / 1),
  ratio4x5('4:5 (Portrait)', 4 / 5);

  final String label;
  final double ratioValue;
  const VideoAspectRatio(this.label, this.ratioValue);
}

/// Video Resolution presets
enum VideoResolution {
  res720p('720p (HD)', 1280, 720),
  res1080p('1080p (Full HD)', 1920, 1080),
  res1440p('1440p (2K)', 2560, 1440),
  res4k('4K (Ultra HD)', 3840, 2160);

  final String label;
  final int baseWidth;
  final int baseHeight;
  const VideoResolution(this.label, this.baseWidth, this.baseHeight);

  /// Computes target pixel dimensions adjusted for project aspect ratio.
  (int width, int height) getDimensions(VideoAspectRatio ratio) {
    switch (ratio) {
      case VideoAspectRatio.ratio16x9:
        return (baseWidth, baseHeight);
      case VideoAspectRatio.ratio9x16:
        return (baseHeight, baseWidth);
      case VideoAspectRatio.ratio1x1:
        return (baseHeight, baseHeight);
      case VideoAspectRatio.ratio4x5:
        return ((baseHeight * 4) ~/ 5, baseHeight);
    }
  }
}

/// Complete Project state containing all media, timing, and export configurations.
@immutable
class Project {
  final String id;
  final String name;
  final List<ImageItem> images;
  final VoiceOver? voiceOver;
  final String? scriptText;

  // Video settings
  final VideoAspectRatio aspectRatio;
  final VideoResolution resolution;
  final int fps;

  const Project({
    required this.id,
    required this.name,
    this.images = const [],
    this.voiceOver,
    this.scriptText,
    this.aspectRatio = VideoAspectRatio.ratio16x9,
    this.resolution = VideoResolution.res1080p,
    this.fps = 30,
  });

  /// Total duration in milliseconds (derived from voice-over or sum of images)
  int get totalDurationMs {
    if (voiceOver != null && voiceOver!.durationMs > 0) {
      return voiceOver!.durationMs;
    }
    if (images.isNotEmpty) {
      return images.last.endMs;
    }
    return 0;
  }

  Project copyWith({
    String? id,
    String? name,
    List<ImageItem>? images,
    VoiceOver? voiceOver,
    bool clearVoiceOver = false,
    String? scriptText,
    VideoAspectRatio? aspectRatio,
    VideoResolution? resolution,
    int? fps,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      images: images ?? this.images,
      voiceOver: clearVoiceOver ? null : (voiceOver ?? this.voiceOver),
      scriptText: scriptText ?? this.scriptText,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      resolution: resolution ?? this.resolution,
      fps: fps ?? this.fps,
    );
  }
}
