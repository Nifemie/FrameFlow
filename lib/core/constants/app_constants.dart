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
    'tiff',
    'jfif',
    'gif',
    'avif',
  ];

  static const List<String> supportedVideoExtensions = [
    'mp4',
    'mov',
    'webm',
    'avi',
    'mkv',
  ];

  static const List<String> supportedAudioExtensions = [
    'mp3',
    'wav',
    'aac',
    'm4a',
    'flac'
  ];

  static List<String> get supportedMediaExtensions => [
    ...supportedVideoExtensions,
    ...supportedImageExtensions,
    ...supportedAudioExtensions,
  ];

  static bool isVideoFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return supportedVideoExtensions.contains(ext);
  }

  static bool isImageFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return supportedImageExtensions.contains(ext);
  }

  static bool isAudioFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return supportedAudioExtensions.contains(ext);
  }
}
