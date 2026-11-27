import 'package:flutter/foundation.dart';

@immutable
class AudioWordCue {
  final String text;
  final int startMs; // Offset within source audio file
  final int endMs;   // Offset within source audio file

  const AudioWordCue({
    required this.text,
    required this.startMs,
    required this.endMs,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'startMs': startMs,
        'endMs': endMs,
      };

  factory AudioWordCue.fromJson(Map<String, dynamic> json) => AudioWordCue(
        text: json['text'] as String? ?? '',
        startMs: json['startMs'] as int? ?? 0,
        endMs: json['endMs'] as int? ?? 0,
      );
}

@immutable
class AudioClipItem {
  final String id;
  final String filePath;
  final String fileName;
  final int startTimelineMs;
  final int fileStartOffsetMs;
  final int durationMs;
  final int? sourceDurationMs;
  final double volume; // 0.0 to 1.5 (1.0 = 100%)
  final int orderIndex;
  final bool isMarked;
  final String? transcriptScript;
  final List<AudioWordCue> wordCues;

  const AudioClipItem({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.startTimelineMs,
    this.fileStartOffsetMs = 0,
    required this.durationMs,
    this.sourceDurationMs,
    this.volume = 1.0,
    required this.orderIndex,
    this.isMarked = false,
    this.transcriptScript,
    this.wordCues = const [],
  });

  int get endTimelineMs => startTimelineMs + durationMs;

  AudioClipItem copyWith({
    String? id,
    String? filePath,
    String? fileName,
    int? startTimelineMs,
    int? fileStartOffsetMs,
    int? durationMs,
    int? sourceDurationMs,
    double? volume,
    int? orderIndex,
    bool? isMarked,
    String? transcriptScript,
    List<AudioWordCue>? wordCues,
  }) {
    return AudioClipItem(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      startTimelineMs: startTimelineMs ?? this.startTimelineMs,
      fileStartOffsetMs: fileStartOffsetMs ?? this.fileStartOffsetMs,
      durationMs: durationMs ?? this.durationMs,
      sourceDurationMs: sourceDurationMs ?? this.sourceDurationMs,
      volume: volume ?? this.volume,
      orderIndex: orderIndex ?? this.orderIndex,
      isMarked: isMarked ?? this.isMarked,
      transcriptScript: transcriptScript ?? this.transcriptScript,
      wordCues: wordCues ?? this.wordCues,
    );
  }
}
