import 'package:flutter/foundation.dart';

enum TrackType { backgroundUnderlay, mainVideo, overlayVideo, text, audio }

@immutable
class TimelineTrackItem {
  final String id;
  final String name;
  final TrackType type;
  final bool isVisible;
  final bool isMuted;
  final int orderIndex;

  const TimelineTrackItem({
    required this.id,
    required this.name,
    required this.type,
    this.isVisible = true,
    this.isMuted = false,
    required this.orderIndex,
  });

  bool get canMute => type == TrackType.audio || type == TrackType.mainVideo || type == TrackType.overlayVideo;
  bool get isUnderlay => type == TrackType.backgroundUnderlay;
  bool get isVideoOrBg => type == TrackType.mainVideo || type == TrackType.backgroundUnderlay || type == TrackType.overlayVideo;

  TimelineTrackItem copyWith({
    String? id,
    String? name,
    TrackType? type,
    bool? isVisible,
    bool? isMuted,
    int? orderIndex,
  }) {
    return TimelineTrackItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isVisible: isVisible ?? this.isVisible,
      isMuted: isMuted ?? this.isMuted,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'isVisible': isVisible,
    'isMuted': isMuted,
    'orderIndex': orderIndex,
  };

  factory TimelineTrackItem.fromJson(Map<String, dynamic> json) => TimelineTrackItem(
    id: json['id'] as String,
    name: json['name'] as String,
    type: TrackType.values.firstWhere((t) => t.name == json['type'], orElse: () => TrackType.mainVideo),
    isVisible: json['isVisible'] as bool? ?? true,
    isMuted: json['isMuted'] as bool? ?? false,
    orderIndex: json['orderIndex'] as int? ?? 0,
  );
}
