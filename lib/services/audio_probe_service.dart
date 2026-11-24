import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

class AudioProbeService {
  static String? _cachedFFprobePath;

  /// Locates the ffprobe executable across multiple environments.
  static Future<String?> findFFprobeAsync() async {
    if (_cachedFFprobePath != null && File(_cachedFFprobePath!).existsSync()) {
      return _cachedFFprobePath;
    }

    // 1. Check system PATH via 'where.exe' on Windows
    try {
      final result = await Process.run('where.exe', ['ffprobe']);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).split(RegExp(r'[\r\n]+')).first.trim();
        if (path.isNotEmpty && File(path).existsSync()) {
          _cachedFFprobePath = path;
          return path;
        }
      }
    } catch (_) {}

    final found = findFFprobe();
    if (found != null) {
      _cachedFFprobePath = found;
    }
    return found;
  }

  /// Locates the ffprobe executable synchronously from candidate paths.
  static String? findFFprobe() {
    if (_cachedFFprobePath != null && File(_cachedFFprobePath!).existsSync()) {
      return _cachedFFprobePath;
    }

    final exeDir = p.dirname(Platform.resolvedExecutable);

    final candidatePaths = [
      // Application / bundle directories
      p.join(exeDir, 'ffprobe.exe'),
      p.join(exeDir, 'assets', 'bin', 'ffprobe.exe'),
      p.join(exeDir, 'data', 'flutter_assets', 'assets', 'bin', 'ffprobe.exe'),
      // Relative workspace directories
      'assets/bin/ffprobe.exe',
      'windows/runner/ffprobe.exe',
      // Installed app directories
      r'C:\Program Files (x86)\FrameFlow Studio\ffprobe.exe',
      r'C:\Program Files (x86)\FrameFlow Studio\assets\bin\ffprobe.exe',
      r'C:\Program Files\FrameFlow Studio\ffprobe.exe',
      // Common FFmpeg directories
      r'C:\Program Files\FFmpeg\bin\ffprobe.exe',
      r'C:\ffmpeg\bin\ffprobe.exe',
      r'D:\ffmpeg\bin\ffprobe.exe',
      r'D:\frameflow\FrameFlow\assets\bin\ffprobe.exe',
    ];

    for (final candidate in candidatePaths) {
      if (File(candidate).existsSync()) {
        _cachedFFprobePath = candidate;
        return candidate;
      }
    }
    return null;
  }

  /// Reliably extracts duration in milliseconds from any audio file.
  static Future<int> getAudioDurationMs(String filePath) async {
    // 1. Try with ffprobe (fastest & 100% reliable)
    final ffprobePath = await findFFprobeAsync();
    if (ffprobePath != null) {
      try {
        final result = await Process.run(ffprobePath, [
          '-v', 'error',
          '-show_entries', 'format=duration',
          '-of', 'default=noprint_wrappers=1:nokey=1',
          filePath,
        ]);

        if (result.exitCode == 0) {
          final out = (result.stdout as String).trim();
          final seconds = double.tryParse(out);
          if (seconds != null && seconds > 0) {
            return (seconds * 1000).round();
          }
        }
      } catch (_) {}
    }

    // 2. Fallback to just_audio player
    final player = AudioPlayer();
    try {
      final initialDuration = await player.setFilePath(filePath);
      if (initialDuration != null && initialDuration.inMilliseconds > 0) {
        return initialDuration.inMilliseconds;
      }
      // Wait for player.duration if initial was null
      final d = await player.durationStream
          .firstWhere((d) => d != null && d.inMilliseconds > 0)
          .timeout(const Duration(seconds: 2));
      return d?.inMilliseconds ?? 0;
    } catch (_) {
      return 0;
    } finally {
      await player.dispose();
    }
  }
}
