import '../../models/project.dart';

class AppConstants {
  static const String appName = 'FrameFlow Studio';
  static const String appVersion = '1.0.0';

  // Default export parameters
  static const int defaultFps = 30;
  static const VideoAspectRatio defaultAspectRatio = VideoAspectRatio.ratio16x9;
  static const VideoResolution defaultResolution = VideoResolution.res1080p;

  // Supported Extensions
  static const List<String> supportedImageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'bmp',
    'tiff'
  ];

  static const List<String> supportedAudioExtensions = [
    'mp3',
    'wav',
    'aac',
    'm4a',
    'flac'
  ];
}
