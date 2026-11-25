import 'package:flutter/material.dart';

/// Represents a user-placed marker/bookmark on the timeline ruler.
@immutable
class TimelineMarker {
  final String id;
  final int timestampMs;
  final String label;
  final int colorValue;

  const TimelineMarker({
    required this.id,
    required this.timestampMs,
    this.label = 'Marker',
    this.colorValue = 0xFFFF5C36,
  });

  Color get color => Color(colorValue);

  TimelineMarker copyWith({
    String? id,
    int? timestampMs,
    String? label,
    int? colorValue,
  }) {
    return TimelineMarker(
      id: id ?? this.id,
      timestampMs: timestampMs ?? this.timestampMs,
      label: label ?? this.label,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestampMs': timestampMs,
        'label': label,
        'colorValue': colorValue,
      };

  factory TimelineMarker.fromMap(Map<String, dynamic> map) {
    return TimelineMarker(
      id: map['id'] as String,
      timestampMs: map['timestampMs'] as int,
      label: map['label'] as String? ?? 'Marker',
      colorValue: map['colorValue'] as int? ?? 0xFFFF5C36,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimelineMarker &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          timestampMs == other.timestampMs &&
          label == other.label &&
          colorValue == other.colorValue;

  @override
  int get hashCode => Object.hash(id, timestampMs, label, colorValue);
}
