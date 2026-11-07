import 'package:flutter/foundation.dart';

/// Represents the imported voice-over audio track that dictates project duration.
@immutable
class VoiceOver {
  final String filePath;
  final String fileName;

  /// Total duration in milliseconds (detected from file metadata)
  final int durationMs;

  const VoiceOver({
    required this.filePath,
    required this.fileName,
    required this.durationMs,
  });

  VoiceOver copyWith({
    String? filePath,
    String? fileName,
    int? durationMs,
  }) {
    return VoiceOver(
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceOver &&
          runtimeType == other.runtimeType &&
          filePath == other.filePath &&
          fileName == other.fileName &&
          durationMs == other.durationMs;

  @override
  int get hashCode =>
      filePath.hashCode ^ fileName.hashCode ^ durationMs.hashCode;

  @override
  String toString() =>
      'VoiceOver(fileName: $fileName, durationMs: $durationMs)';
}
