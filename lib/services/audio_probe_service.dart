import 'dart:io';
import 'package:just_audio/just_audio.dart';

class AudioProbeService {
  /// Locates the ffprobe executable.
  static String? findFFprobe() {
    final candidatePaths = [
      r'C:\Users\USER\Desktop\frameflow\assets\bin\ffprobe.exe',
      'assets/bin/ffprobe.exe',
      'windows/runner/ffprobe.exe',
    ];

    for (final p in candidatePaths) {
      if (File(p).existsSync()) return p;
    }
    return null;
  }

  /// Reliably extracts duration in milliseconds from any audio file.
  static Future<int> getAudioDurationMs(String filePath) async {
    // 1. Try with bundled ffprobe (fastest & 100% reliable)
    final ffprobePath = findFFprobe();
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
