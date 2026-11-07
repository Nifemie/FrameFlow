import 'dart:convert';
import 'dart:io';
import '../core/utils/time_parser.dart';
import '../features/export/models/export_config.dart';
import '../models/project.dart';

class FFmpegService {
  Process? _activeProcess;
  bool _isCancelled = false;

  /// Finds the ffmpeg executable on the system or bundled directory.
  static Future<String?> findFFmpeg() async {
    // 1. Check system PATH via 'where' on Windows
    try {
      final result = await Process.run('where.exe', ['ffmpeg']);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).split(RegExp(r'[\r\n]+')).first.trim();
        if (path.isNotEmpty && File(path).existsSync()) return path;
      }
    } catch (_) {}

    // 2. Check local project or common installation paths
    final candidatePaths = [
      r'C:\Users\USER\Desktop\frameflow\assets\bin\ffmpeg.exe',
      'assets/bin/ffmpeg.exe',
      'windows/runner/ffmpeg.exe',
      r'C:\Program Files\FFmpeg\bin\ffmpeg.exe',
      r'C:\ffmpeg\bin\ffmpeg.exe',
    ];

    for (final p in candidatePaths) {
      if (File(p).existsSync()) return p;
    }

    return null;
  }

  /// Cancels the currently active rendering process.
  void cancel() {
    _isCancelled = true;
    _activeProcess?.kill();
    _activeProcess = null;
  }

  /// Renders the project video with progress updates (0.0 to 1.0).
  Future<bool> renderVideo({
    required Project project,
    required ExportConfig config,
    required void Function(double progress, String status) onProgress,
  }) async {
    _isCancelled = false;
    final ffmpegPath = await findFFmpeg();
    if (ffmpegPath == null) {
      throw Exception('FFmpeg executable not found. Please install FFmpeg on your system.');
    }

    if (project.images.isEmpty) {
      throw Exception('Project has no images to export.');
    }

    // Create temporary folder for concat script
    final tempDir = Directory.systemTemp.createTempSync('frameflow_export_');
    final concatFile = File('${tempDir.path}\\concat.txt');

    try {
      // 1. Generate FFmpeg concat script
      final buffer = StringBuffer();
      buffer.writeln('ffconcat version 1.0');

      for (int i = 0; i < project.images.length; i++) {
        final item = project.images[i];
        final durSec = (item.durationMs / 1000).toStringAsFixed(3);
        // Concat format requires forward slashes or escaped backslashes
        final safePath = item.filePath.replaceAll(r'\', '/');
        buffer.writeln("file '$safePath'");
        buffer.writeln('duration $durSec');
      }

      // Concat demuxer requirement: repeat the last file to set duration
      final lastSafePath = project.images.last.filePath.replaceAll(r'\', '/');
      buffer.writeln("file '$lastSafePath'");
      await concatFile.writeAsString(buffer.toString());

      // 2. Dimensions & Filter chain
      final (width, height) = config.outputDimensions;
      final vf = 'scale=$width:$height:force_original_aspect_ratio=decrease,'
          'pad=$width:$height:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p';

      final totalDurationSec = (project.totalDurationMs / 1000);

      // 3. Assemble FFmpeg CLI arguments
      final args = <String>[
        '-y', // Overwrite output
        '-f', 'concat',
        '-safe', '0',
        '-i', concatFile.path,
      ];

      if (project.voiceOver != null && File(project.voiceOver!.filePath).existsSync()) {
        args.addAll(['-i', project.voiceOver!.filePath]);
      } else {
        // Generate silent audio so export has standard audio track
        args.addAll(['-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100']);
      }

      args.addAll([
        '-vf', vf,
        '-r', '${config.fps}',
        '-c:v', 'libx264',
        '-preset', 'medium',
        '-crf', '20',
        '-c:a', 'aac',
        '-b:a', '192k',
        '-shortest',
        config.outputPath,
      ]);

      onProgress(0.05, 'Starting video encoding...');

      // 4. Run Process and parse progress
      _activeProcess = await Process.start(ffmpegPath, args);

      _activeProcess!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        // Parse time=HH:MM:SS.ms from FFmpeg stderr output
        final match = RegExp(r'time=(\d{2}:\d{2}:\d{2}\.\d+)').firstMatch(line);
        if (match != null) {
          final timeStr = match.group(1)!;
          final currentMs = TimeParser.parseToMs(timeStr) ?? 0;
          if (totalDurationSec > 0) {
            final progress = ((currentMs / 1000) / totalDurationSec).clamp(0.05, 0.98);
            onProgress(progress, 'Rendering: $timeStr');
          }
        }
      });

      final exitCode = await _activeProcess!.exitCode;
      _activeProcess = null;

      if (_isCancelled) {
        if (File(config.outputPath).existsSync()) {
          try { File(config.outputPath).deleteSync(); } catch (_) {}
        }
        return false;
      }

      if (exitCode == 0) {
        onProgress(1.0, 'Rendering Complete!');
        return true;
      } else {
        throw Exception('FFmpeg failed with exit code $exitCode');
      }
    } finally {
      try { tempDir.deleteSync(recursive: true); } catch (_) {}
    }
  }
}
