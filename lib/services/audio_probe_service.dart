import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'ffmpeg_service.dart';

class AudioProbeService {
  static String? _cachedFFprobePath;
  static final Map<String, List<double>> _waveformCache = {};
  static final Map<String, Future<List<double>?>> _pendingWaveforms = {};
  static const int waveformBinsPerSecond = 20;

  static List<double>? getCachedWaveformPeaks(String filePath) => _waveformCache[filePath];

  /// Extracts real normalized PCM amplitude peaks (20 bins/sec = 1 bin per 50ms) via FFmpeg.
  static Future<List<double>?> getWaveformPeaks(String filePath) async {
    if (_waveformCache.containsKey(filePath)) return _waveformCache[filePath];
    if (_pendingWaveforms.containsKey(filePath)) return _pendingWaveforms[filePath];

    final future = _extractWaveformPeaks(filePath);
    _pendingWaveforms[filePath] = future;
    try {
      return await future;
    } finally {
      _pendingWaveforms.remove(filePath);
    }
  }

  static Future<List<double>?> _extractWaveformPeaks(String filePath) async {
    if (!File(filePath).existsSync()) return null;
    final ffmpeg = await FFmpegService.findFFmpeg();
    if (ffmpeg == null) return null;

    try {
      const sampleRate = 2000;
      final proc = await Process.start(ffmpeg, [
        '-v', 'error',
        '-i', filePath,
        '-vn',
        '-ac', '1',
        '-ar', '$sampleRate',
        '-f', 's16le',
        'pipe:1',
      ]);

      final builder = BytesBuilder(copy: false);
      await for (final chunk in proc.stdout) {
        builder.add(chunk);
      }
      final exitCode = await proc.exitCode;
      if (exitCode != 0) return null;

      final bytes = builder.takeBytes();
      if (bytes.length < 4) return null;

      final evenLen = bytes.length - (bytes.length % 2);
      final byteData = ByteData.sublistView(bytes, 0, evenLen);
      final totalSamples = evenLen ~/ 2;
      const samplesPerBin = sampleRate ~/ waveformBinsPerSecond; // 100 samples = 50ms
      final binCount = (totalSamples / samplesPerBin).ceil();
      final peaks = List<double>.filled(binCount, 0.0);

      double globalMax = 0.0;
      for (int b = 0; b < binCount; b++) {
        final startSample = b * samplesPerBin;
        final endSample = (startSample + samplesPerBin).clamp(0, totalSamples);
        int maxAbs = 0;
        for (int s = startSample; s < endSample; s++) {
          final v = byteData.getInt16(s * 2, Endian.little).abs();
          if (v > maxAbs) maxAbs = v;
        }
        final norm = maxAbs / 32768.0;
        peaks[b] = norm;
        if (norm > globalMax) globalMax = norm;
      }

      if (globalMax > 0.01) {
        for (int b = 0; b < binCount; b++) {
          peaks[b] = (peaks[b] / globalMax).clamp(0.0, 1.0);
        }
      }

      _waveformCache[filePath] = peaks;
      return peaks;
    } catch (_) {
      return null;
    }
  }

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

  /// Checks whether a media/video file contains an audio stream.
  static Future<bool> hasAudioStream(String filePath) async {
    final ffprobePath = findFFprobe();
    if (ffprobePath != null) {
      try {
        final result = await Process.run(ffprobePath, [
          '-v', 'error',
          '-select_streams', 'a',
          '-show_entries', 'stream=codec_type',
          '-of', 'default=noprint_wrappers=1:nokey=1',
          filePath,
        ]);
        if (result.exitCode == 0) {
          final out = (result.stdout as String).trim();
          return out.isNotEmpty;
        }
      } catch (_) {}
    }
    return false;
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
