import 'package:flutter/foundation.dart';
import '../../../models/project.dart';

@immutable
class ExportConfig {
  final VideoResolution resolution;
  final VideoAspectRatio aspectRatio;
  final int fps;
  final String outputPath;

  const ExportConfig({
    required this.resolution,
    required this.aspectRatio,
    required this.fps,
    required this.outputPath,
  });

  (int width, int height) get outputDimensions =>
      resolution.getDimensions(aspectRatio);
}
