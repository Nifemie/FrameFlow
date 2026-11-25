import 'package:flutter/foundation.dart';

@immutable
class AudioClipItem {
  final String id;
  final String filePath;
  final String fileName;
  final int startTimelineMs;
  final int fileStartOffsetMs;
  final int durationMs;
  final double volume; // 0.0 to 1.5 (1.0 = 100%)
  final int orderIndex;
  final bool isMarked;

  const AudioClipItem({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.startTimelineMs,
    this.fileStartOffsetMs = 0,
    required this.durationMs,
    this.volume = 1.0,
    required this.orderIndex,
    this.isMarked = false,
  });

  int get endTimelineMs => startTimelineMs + durationMs;

  AudioClipItem copyWith({
    String? id,
    String? filePath,
    String? fileName,
    int? startTimelineMs,
    int? fileStartOffsetMs,
    int? durationMs,
    double? volume,
    int? orderIndex,
    bool? isMarked,
  }) {
    return AudioClipItem(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      startTimelineMs: startTimelineMs ?? this.startTimelineMs,
      fileStartOffsetMs: fileStartOffsetMs ?? this.fileStartOffsetMs,
      durationMs: durationMs ?? this.durationMs,
      volume: volume ?? this.volume,
      orderIndex: orderIndex ?? this.orderIndex,
      isMarked: isMarked ?? this.isMarked,
    );
  }
}
