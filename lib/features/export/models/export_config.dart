import 'package:flutter/foundation.dart';
import '../../../models/project.dart';

enum ExportFormat {
  mp4('.mp4', 'MP4 (Standard / Web)'),
  mov('.mov', 'MOV (Apple QuickTime)'),
  mkv('.mkv', 'MKV (Matroska)');

  final String extension;
  final String label;
  const ExportFormat(this.extension, this.label);
}

enum VideoCodec {
  h264('libx264', 'H.264 (Broad Compatibility)'),
  h265('libx265', 'H.265 / HEVC (High Efficiency)');

  final String ffmpegCodec;
  final String label;
  const VideoCodec(this.ffmpegCodec, this.label);
}

enum QualityPreset {
  low(28, 'Low (Smaller File)'),
  medium(23, 'Medium (Standard)'),
  high(18, 'High (Crisp / Production)'),
  veryHigh(14, 'Very High (Near Lossless)');

  final int crf;
  final String label;
  const QualityPreset(this.crf, this.label);
}

@immutable
class ExportConfig {
  final VideoResolution resolution;
  final VideoAspectRatio aspectRatio;
  final int fps;
  final String outputPath;
  final ExportFormat format;
  final VideoCodec codec;
  final QualityPreset quality;

  const ExportConfig({
    required this.resolution,
    required this.aspectRatio,
    required this.fps,
    required this.outputPath,
    this.format = ExportFormat.mp4,
    this.codec = VideoCodec.h264,
    this.quality = QualityPreset.high,
  });

  (int width, int height) get outputDimensions => resolution.getDimensions(aspectRatio);
}
