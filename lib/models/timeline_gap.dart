import 'package:flutter/foundation.dart';

/// Represents an explicitly created blank space on a timeline track
/// (created either by deleting a clip in-place or via "Create Blank Space").
@immutable
class TimelineGap {
  final String id;
  final String trackId;
  final int startMs;
  final int endMs;

  const TimelineGap({
    required this.id,
    required this.trackId,
    required this.startMs,
    required this.endMs,
  });

  int get durationMs => (endMs - startMs).clamp(0, 36000000);

  TimelineGap copyWith({
    String? id,
    String? trackId,
    int? startMs,
    int? endMs,
  }) {
    return TimelineGap(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'trackId': trackId,
        'startMs': startMs,
        'endMs': endMs,
      };

  factory TimelineGap.fromMap(Map<String, dynamic> map) => TimelineGap(
        id: map['id'] as String,
        trackId: map['trackId'] as String? ?? 'track_v1',
        startMs: map['startMs'] as int,
        endMs: map['endMs'] as int,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineGap &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          trackId == other.trackId &&
          startMs == other.startMs &&
          endMs == other.endMs;

  @override
  int get hashCode => Object.hash(id, trackId, startMs, endMs);
}
