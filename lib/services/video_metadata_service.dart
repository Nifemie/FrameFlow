import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'audio_probe_service.dart';
import 'ffmpeg_service.dart';

class VideoMetadataService {
  static final Map<String, Size> _dimensionsCache = {};
  static final Map<String, int> _durationCache = {};
  static final Map<String, String> _thumbnailCache = {};
  static final Map<String, String> _audioTrackCache = {};
  static final Set<String> _pendingThumbnails = {};
  static final Set<String> _pendingAudioTracks = {};

  static Size? getCachedDimensions(String path) => _dimensionsCache[path];
  static int? getCachedDuration(String path) => _durationCache[path];
  static String? getCachedThumbnail(String path) => _thumbnailCache[path];
  static String? getCachedAudioTrack(String path) => _audioTrackCache[path];

  /// Extracts or returns cached audio stream (m4a/aac) for a video file.
  static Future<String?> getAudioTrackPath(String videoPath) async {
    if (_audioTrackCache.containsKey(videoPath)) {
      final cached = _audioTrackCache[videoPath]!;
      if (File(cached).existsSync()) return cached;
    }

    if (_pendingAudioTracks.contains(videoPath)) return null;
    _pendingAudioTracks.add(videoPath);

    try {
      final ffmpeg = await FFmpegService.findFFmpeg();
      if (ffmpeg == null) return null;

      final tempDir = await getTemporaryDirectory();
      final audioDir = Directory('${tempDir.path}\\frameflow_audio');
      if (!audioDir.existsSync()) audioDir.createSync(recursive: true);

      final safeName = p.basenameWithoutExtension(videoPath).replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final audioPath = '${audioDir.path}\\audio_${safeName}_${videoPath.hashCode.abs()}.m4a';
      final audioFile = File(audioPath);

      if (audioFile.existsSync() && audioFile.lengthSync() > 100) {
        _audioTrackCache[videoPath] = audioPath;
        return audioPath;
      }

      // Fast lossless stream copy of the audio channel (takes ~100ms)
      final res = await Process.run(ffmpeg, [
        '-y',
        '-i', videoPath,
        '-vn',
        '-c:a', 'copy',
        audioPath,
      ]);

      if (res.exitCode == 0 && audioFile.existsSync() && audioFile.lengthSync() > 100) {
        _audioTrackCache[videoPath] = audioPath;
        return audioPath;
      }

      // Fallback: re-encode audio to AAC if direct copy failed (e.g. PCM or AC3 input)
      final resFallback = await Process.run(ffmpeg, [
        '-y',
        '-i', videoPath,
        '-vn',
        '-c:a', 'aac',
        '-b:a', '192k',
        audioPath,
      ]);

      if (resFallback.exitCode == 0 && audioFile.existsSync() && audioFile.lengthSync() > 100) {
        _audioTrackCache[videoPath] = audioPath;
        return audioPath;
      }
    } catch (_) {
    } finally {
      _pendingAudioTracks.remove(videoPath);
    }
    return null;
  }

  /// Resolves video duration (in milliseconds) using bundled ffprobe.
  static Future<int> resolveDuration(String videoPath) async {
    if (_durationCache.containsKey(videoPath)) return _durationCache[videoPath]!;
    final dur = await AudioProbeService.getAudioDurationMs(videoPath);
    if (dur > 0) {
      _durationCache[videoPath] = dur;
      return dur;
    }
    return 5000;
  }

  /// Extracts or returns cached thumbnail image for video.
  static Future<String?> getThumbnailPath(String videoPath) async {
    if (_thumbnailCache.containsKey(videoPath)) {
      final cached = _thumbnailCache[videoPath]!;
      if (File(cached).existsSync()) return cached;
    }

    if (_pendingThumbnails.contains(videoPath)) return null;
    _pendingThumbnails.add(videoPath);

    try {
      final ffmpeg = await FFmpegService.findFFmpeg();
      if (ffmpeg == null) return null;

      final tempDir = await getTemporaryDirectory();
      final thumbsDir = Directory('${tempDir.path}\\frameflow_thumbs');
      if (!thumbsDir.existsSync()) thumbsDir.createSync(recursive: true);

      final safeName = p.basenameWithoutExtension(videoPath).replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final thumbPath = '${thumbsDir.path}\\thumb_${safeName}_${videoPath.hashCode.abs()}.jpg';
      final thumbFile = File(thumbPath);

      if (thumbFile.existsSync() && thumbFile.lengthSync() > 0) {
        _thumbnailCache[videoPath] = thumbPath;
        return thumbPath;
      }

      final res = await Process.run(ffmpeg, [
        '-y',
        '-ss', '00:00:00.25',
        '-i', videoPath,
        '-vframes', '1',
        '-vf', 'scale=640:-1',
        '-q:v', '3',
        thumbPath,
      ]);

      if (res.exitCode == 0 && thumbFile.existsSync()) {
        _thumbnailCache[videoPath] = thumbPath;
        return thumbPath;
      }
    } catch (_) {
    } finally {
      _pendingThumbnails.remove(videoPath);
    }
    return null;
  }
}
