import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/image_item.dart';

class VideoPlaybackEngine {
  static Player? _player;
  static VideoController? _controller;
  static String? _currentFilePath;
  static String? _currentClipId;
  static bool _isInitialized = false;
  static bool _isOpening = false;
  static int? _forcedPositionMs;

  static bool get isTestEnvironment =>
      Platform.environment.containsKey('FLUTTER_TEST') || kIsWeb;

  static bool get isAvailable {
    _ensureInitialized();
    return !isTestEnvironment && _player != null && _controller != null;
  }

  static Player get player {
    _ensureInitialized();
    return _player!;
  }

  static VideoController get controller {
    _ensureInitialized();
    return _controller!;
  }

  static void ensureInitialized() {
    _ensureInitialized();
  }

  static void _ensureInitialized() {
    if (_isInitialized) return;
    _isInitialized = true;
    if (isTestEnvironment) return;

    try {
      _player = Player();
      _player!.stream.position.listen((pos) {
        if (_forcedPositionMs != null) {
          final diff = (pos.inMilliseconds - _forcedPositionMs!).abs();
          if (diff < 500) {
            _forcedPositionMs = null;
          }
        }
      });
      _controller = VideoController(
        _player!,
        configuration: const VideoControllerConfiguration(
          enableHardwareAcceleration: true,
          hwdec: 'auto',
        ),
      );
      _configurePerformanceProperties();
    } catch (e) {
      debugPrint('VideoPlaybackEngine._ensureInitialized error: $e');
    }
  }

  static Future<void> _configurePerformanceProperties() async {
    if (_player == null || isTestEnvironment) return;
    try {
      final p = _player!.platform as dynamic;
      await p.setProperty('hwdec', 'auto');
      await p.setProperty('video-sync', 'audio');
      await p.setProperty('framedrop', 'vo');
      await p.setProperty('demuxer-max-bytes', '64MiB');
      await p.setProperty('vd-lavc-threads', '4');
    } catch (_) {}
  }

  static String? get currentFilePath => _currentFilePath;
  static String? get currentClipId => _currentClipId;
  static bool get isPlaying => _player?.state.playing ?? false;
  static bool get isOpening => _isOpening;
  static int get positionMs {
    if (_forcedPositionMs != null) return _forcedPositionMs!;
    return _player?.state.position.inMilliseconds ?? 0;
  }

  /// Prepares a video item paused at [offsetMs].
  static Future<void> prepareVideo(ImageItem? videoItem, int offsetMs) async {
    if (isTestEnvironment) return;
    _ensureInitialized();
    if (_player == null || videoItem == null || !videoItem.isVideo) return;
    if (!File(videoItem.filePath).existsSync()) return;

    try {
      final isDifferentClip = _currentClipId != videoItem.id;
      final isDifferentFile = _currentFilePath != videoItem.filePath;
      _currentClipId = videoItem.id;
      _currentFilePath = videoItem.filePath;

      if (isDifferentFile || isDifferentClip) {
        _isOpening = true;
        await _player!.open(
          Media(videoItem.filePath, start: Duration(milliseconds: offsetMs)),
          play: false,
        );
        _isOpening = false;
      } else {
        final curPos = _player!.state.position.inMilliseconds;
        if ((curPos - offsetMs).abs() > 60) {
          await _player!.seek(Duration(milliseconds: offsetMs));
        }
      }
    } catch (e) {
      _isOpening = false;
      debugPrint('VideoPlaybackEngine.prepareVideo error: $e');
    }
  }

  /// Starts playback of [videoItem] at [offsetMs].
  static Future<void> playVideo(
    ImageItem videoItem,
    int offsetMs, {
    required bool isMuted,
  }) async {
    if (isTestEnvironment) return;
    _ensureInitialized();
    if (_player == null || !videoItem.isVideo) return;
    if (!File(videoItem.filePath).existsSync()) return;

    try {
      final targetVolume = isMuted ? 0.0 : 100.0;
      if (_player!.state.volume != targetVolume) {
        await _player!.setVolume(targetVolume);
      }

      final isDifferentClip = _currentClipId != videoItem.id;
      final isDifferentFile = _currentFilePath != videoItem.filePath;
      _currentClipId = videoItem.id;
      _currentFilePath = videoItem.filePath;
      _forcedPositionMs = offsetMs;

      if (isDifferentFile || isDifferentClip) {
        _isOpening = true;
        await _player!.open(
          Media(videoItem.filePath, start: Duration(milliseconds: offsetMs)),
          play: true,
        );
        _isOpening = false;
      } else {
        final curPos = _player!.state.position.inMilliseconds;
        if ((curPos - offsetMs).abs() > 100) {
          await _player!.seek(Duration(milliseconds: offsetMs));
        }
        if (!_player!.state.playing) {
          await _player!.play();
        }
      }
    } catch (e) {
      _isOpening = false;
      debugPrint('VideoPlaybackEngine.playVideo error: $e');
    }
  }

  /// Pauses video playback.
  static Future<void> pauseVideo() async {
    if (isTestEnvironment || _player == null) return;
    try {
      if (_player!.state.playing) {
        await _player!.pause();
      }
    } catch (e) {
      debugPrint('VideoPlaybackEngine.pauseVideo error: $e');
    }
  }

  /// Seeks the current video to [offsetMs].
  static Future<void> seekVideo(int offsetMs) async {
    if (isTestEnvironment || _player == null || _isOpening) return;
    try {
      await _player!.seek(Duration(milliseconds: offsetMs));
    } catch (e) {
      debugPrint('VideoPlaybackEngine.seekVideo error: $e');
    }
  }

  /// Sets audio volume / mute.
  static Future<void> setVolume(double volumePercent) async {
    if (isTestEnvironment || _player == null) return;
    try {
      await _player!.setVolume(volumePercent.clamp(0.0, 100.0));
    } catch (e) {
      debugPrint('VideoPlaybackEngine.setVolume error: $e');
    }
  }

  static void dispose() {
    if (isTestEnvironment) return;
    try {
      _player?.dispose();
    } catch (_) {}
  }
}
