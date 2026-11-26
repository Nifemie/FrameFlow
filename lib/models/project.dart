import 'package:flutter/foundation.dart';
import 'audio_clip_item.dart';
import 'image_item.dart';
import 'text_overlay_item.dart';
import 'timeline_marker.dart';
import 'timeline_track_item.dart';
import 'voice_over.dart';

enum TimingMode {
  automatic('Auto Sync', 'Auto-calculates start/end and snaps to audio'),
  manual('Manual Timing', 'Independent start/end/duration adjustments');
  final String label, description;
  const TimingMode(this.label, this.description);
}

enum VideoAspectRatio {
  ratio16x9('16:9', 16 / 9), ratio9x16('9:16 (Shorts/Reels)', 9 / 16),
  ratio1x1('1:1 (Square)', 1 / 1), ratio4x5('4:5 (Portrait)', 4 / 5);
  final String label; final double ratioValue;
  const VideoAspectRatio(this.label, this.ratioValue);
}

enum VideoResolution {
  res720p('720p (HD)', 1280, 720), res1080p('1080p (Full HD)', 1920, 1080),
  res1440p('1440p (2K)', 2560, 1440), res4k('4K (Ultra HD)', 3840, 2160);
  final String label; final int baseWidth, baseHeight;
  const VideoResolution(this.label, this.baseWidth, this.baseHeight);

  (int width, int height) getDimensions(VideoAspectRatio ratio) {
    switch (ratio) {
      case VideoAspectRatio.ratio16x9: return (baseWidth, baseHeight);
      case VideoAspectRatio.ratio9x16: return (baseHeight, baseWidth);
      case VideoAspectRatio.ratio1x1: return (baseHeight, baseHeight);
      case VideoAspectRatio.ratio4x5: return ((baseHeight * 4) ~/ 5, baseHeight);
    }
  }
}

@immutable
class Project {
  final String id, name;
  final List<ImageItem> images;
  final VoiceOver? voiceOver;
  final List<AudioClipItem> audioClips;
  final List<TextOverlayItem> textOverlays;
  final List<TimelineTrackItem> tracks;
  final List<TimelineMarker> markers;
  final String? scriptText;
  final TimingMode timingMode;
  final VideoAspectRatio aspectRatio;
  final VideoResolution resolution;
  final int fps;

  static List<TimelineTrackItem> get defaultTracks => const [
    TimelineTrackItem(id: 'track_v1', name: 'Assets 1', type: TrackType.mainVideo, orderIndex: 0),
  ];

  const Project({
    required this.id, required this.name,
    this.images = const [], this.voiceOver,
    this.audioClips = const [], this.textOverlays = const [],
    this.tracks = const [], this.markers = const [],
    this.scriptText, this.timingMode = TimingMode.automatic,
    this.aspectRatio = VideoAspectRatio.ratio16x9,
    this.resolution = VideoResolution.res1080p, this.fps = 30,
  });

  List<TimelineTrackItem> get effectiveTracks {
    final list = List<TimelineTrackItem>.from(tracks.isNotEmpty ? tracks : defaultTracks);
    if (!list.any((t) => t.id == 'track_v1' || t.type == TrackType.mainVideo)) {
      list.insert(0, const TimelineTrackItem(id: 'track_v1', name: 'Assets 1', type: TrackType.mainVideo, orderIndex: 0));
    }
    // Auto-reveal Audio Track if voice-over or audio clips exist
    if ((audioClips.isNotEmpty || voiceOver != null) && !list.any((t) => t.type == TrackType.audio)) {
      list.add(const TimelineTrackItem(id: 'track_a1', name: 'Audio Track', type: TrackType.audio, orderIndex: 3));
    }
    // Auto-reveal Text Track if text overlays exist
    if (textOverlays.isNotEmpty && !list.any((t) => t.type == TrackType.text)) {
      list.add(const TimelineTrackItem(id: 'track_t1', name: 'Text / Titles', type: TrackType.text, orderIndex: 2));
    }
    // Auto-reveal BG Underlay Track if clips are assigned to track_bg
    if (images.any((img) => img.trackId == 'track_bg') && !list.any((t) => t.type == TrackType.backgroundUnderlay)) {
      list.add(const TimelineTrackItem(id: 'track_bg', name: 'BG (Underlay)', type: TrackType.backgroundUnderlay, orderIndex: 1));
    }
    list.sort((a, b) {
      int rank(TrackType t) {
        switch (t) {
          case TrackType.overlayVideo: return 0;
          case TrackType.mainVideo: return 1;
          case TrackType.backgroundUnderlay: return 2;
          case TrackType.text: return 3;
          case TrackType.audio: return 4;
        }
      }
      final rA = rank(a.type), rB = rank(b.type);
      if (rA != rB) return rA.compareTo(rB);
      return a.orderIndex.compareTo(b.orderIndex);
    });
    return list;
  }

  List<ImageItem> imagesForTrack(String trackId) => images.where((i) => i.trackId == trackId).toList();

  bool isTrackVisible(String trackId) {
    final t = effectiveTracks.where((tr) => tr.id == trackId).firstOrNull;
    return t != null ? t.isVisible : true;
  }

  bool isTrackMuted(String trackId) {
    final t = effectiveTracks.where((tr) => tr.id == trackId).firstOrNull;
    return t != null ? t.isMuted : false;
  }

  bool get isAudioMuted => effectiveTracks.any((tr) => tr.type == TrackType.audio && tr.isMuted);

  int get totalAudioDurationMs => audioClips.isNotEmpty ? audioClips.map((a) => a.endTimelineMs).reduce((a, b) => a > b ? a : b) : (voiceOver?.durationMs ?? 0);
  List<AudioClipItem> get effectiveAudioClips {
    if (audioClips.isNotEmpty) return audioClips;
    if (voiceOver != null) return [AudioClipItem(id: 'vo_default', filePath: voiceOver!.filePath, fileName: voiceOver!.fileName, startTimelineMs: 0, durationMs: voiceOver!.durationMs, orderIndex: 0)];
    return const [];
  }
  int get totalImageDurationMs => images.isNotEmpty ? images.map((i) => i.endMs).reduce((a, b) => a > b ? a : b) : 0;
  int get totalDurationMs {
    final i = totalImageDurationMs, a = totalAudioDurationMs;
    return i > a ? i : a;
  }

  Project copyWith({
    String? id, String? name, List<ImageItem>? images, VoiceOver? voiceOver,
    List<AudioClipItem>? audioClips, List<TextOverlayItem>? textOverlays,
    List<TimelineTrackItem>? tracks, List<TimelineMarker>? markers,
    bool clearVoiceOver = false,
    String? scriptText, TimingMode? timingMode, VideoAspectRatio? aspectRatio,
    VideoResolution? resolution, int? fps,
  }) {
    return Project(
      id: id ?? this.id, name: name ?? this.name, images: images ?? this.images,
      voiceOver: clearVoiceOver ? null : (voiceOver ?? this.voiceOver),
      audioClips: clearVoiceOver ? const [] : (audioClips ?? this.audioClips),
      textOverlays: textOverlays ?? this.textOverlays,
      tracks: tracks ?? this.tracks,
      markers: markers ?? this.markers,
      scriptText: scriptText ?? this.scriptText, timingMode: timingMode ?? this.timingMode,
      aspectRatio: aspectRatio ?? this.aspectRatio, resolution: resolution ?? this.resolution, fps: fps ?? this.fps,
    );
  }
}
