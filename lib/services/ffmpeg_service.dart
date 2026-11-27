import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../core/utils/time_parser.dart';
import '../features/export/models/export_config.dart';
import '../models/audio_clip_item.dart';
import '../models/image_item.dart';
import '../models/project.dart';
import '../models/text_overlay_item.dart';
import 'audio_probe_service.dart';
import 'ffmpeg_animation_filter_builder.dart';
import 'project_slice_service.dart';

class FFmpegService {
  Process? _activeProcess;
  bool _isCancelled = false;

  static Future<String?> findFFmpeg() async {
    for (final p in [r'C:\Users\USER\Desktop\frameflow\assets\bin\ffmpeg.exe', 'assets/bin/ffmpeg.exe', 'windows/runner/ffmpeg.exe', r'C:\Program Files\FFmpeg\bin\ffmpeg.exe']) { if (File(p).existsSync()) return p; }
    try {
      final res = await Process.run('where.exe', ['ffmpeg']);
      if (res.exitCode == 0) { final p = (res.stdout as String).split(RegExp(r'[\r\n]+')).first.trim(); if (p.isNotEmpty && File(p).existsSync()) return p; }
    } catch (_) {}
    return null;
  }

  void cancel() { _isCancelled = true; _activeProcess?.kill(); _activeProcess = null; }

  static String? _findDefaultSystemFont() {
    if (!Platform.isWindows) return null;
    for (final p in const [r'C:\Windows\Fonts\arial.ttf', r'C:\Windows\Fonts\segoeui.ttf', r'C:\Windows\Fonts\calibri.ttf']) { if (File(p).existsSync()) return p; }
    return null;
  }

  static String? _resolveFontPath(String family, String? customPath) {
    if (customPath != null && File(customPath).existsSync()) return customPath;
    if (Platform.isWindows) {
      final map = {'impact': r'C:\Windows\Fonts\impact.ttf', 'times new roman': r'C:\Windows\Fonts\times.ttf', 'courier new': r'C:\Windows\Fonts\cour.ttf', 'georgia': r'C:\Windows\Fonts\georgia.ttf', 'arial': r'C:\Windows\Fonts\arial.ttf', 'segoe ui': r'C:\Windows\Fonts\segoeui.ttf'};
      final f = map[family.toLowerCase().trim()];
      if (f != null && File(f).existsSync()) return f;
    }
    return _findDefaultSystemFont();
  }

  Future<bool> renderVideo({
    required Project project,
    required ExportConfig config,
    required void Function(double progress, String status) onProgress,
    int? rangeStartMs,
    int? rangeEndMs,
  }) async {
    _isCancelled = false;
    final ffmpegPath = await findFFmpeg();
    if (ffmpegPath == null) throw Exception('FFmpeg executable not found.');

    final isRange = rangeStartMs != null && rangeEndMs != null && rangeEndMs > rangeStartMs;
    final activeProject = isRange
        ? ProjectSliceService.sliceProject(project, rangeStartMs, rangeEndMs)
        : project;
    final targetDurationMs = isRange ? (rangeEndMs - rangeStartMs) : activeProject.totalDurationMs;
    if (!isRange && activeProject.images.isEmpty) throw Exception('Project has no images to export.');
    if (targetDurationMs <= 0) throw Exception('Export duration must be greater than 0.');

    final tempDir = Directory.systemTemp.createTempSync('frameflow_export_');
    final concatFile = File('${tempDir.path}\\concat.txt'), blackMp4 = File('${tempDir.path}\\black.mp4');

    try {
      final (width, height) = config.outputDimensions;
      File(config.outputPath).parent.createSync(recursive: true);
      await Process.run(ffmpegPath, [
        '-y',
        '-f', 'lavfi', '-i', 'color=c=black:s=${width}x$height:d=1:r=${config.fps}',
        '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
        '-c:v', 'libx264', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-ar', '44100', '-ac', '2', '-t', '1',
        blackMp4.path,
      ]);
      final safeBlackPath = blackMp4.path.replaceAll(r'\', '/');

      final exportClips = List<ImageItem>.from(activeProject.images)..sort((a, b) => a.startMs.compareTo(b.startMs));
      final normPaths = List<String>.filled(exportClips.length, safeBlackPath);

      // Concurrency worker pool (run up to 6 clips in parallel across CPU cores)
      final poolSize = Platform.numberOfProcessors.clamp(2, 6);
      int nextIdx = 0;
      int completedCount = 0;

      Future<void> worker() async {
        while (!_isCancelled) {
          int i;
          if (nextIdx >= exportClips.length) break;
          i = nextIdx++;
          final img = exportClips[i], durSec = max(0.2, img.durationMs / 1000.0), target = File('${tempDir.path}\\norm_$i.mp4');
          final clipVf = FFmpegAnimationFilterBuilder.buildClipFilter(item: img, width: width, height: height, fps: config.fps);
          final isMuted = !activeProject.isTrackVisible(img.trackId) || img.isMuted || activeProject.isTrackMuted(img.trackId);

          if (img.isColorBackground) {
            final hex = (img.backgroundColorValue ?? 0xFF000000).toRadixString(16).padLeft(8, '0').substring(2);
            await Process.run(ffmpegPath, [
              '-y',
              '-f', 'lavfi', '-i', 'color=c=0x$hex:s=${width}x$height:d=$durSec:r=${config.fps}',
              '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
              if (clipVf.isNotEmpty) ...['-vf', clipVf],
              '-c:v', 'libx264', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p',
              '-c:a', 'aac', '-ar', '44100', '-ac', '2',
              '-t', durSec.toStringAsFixed(3),
              target.path,
            ]);
            if (target.existsSync()) normPaths[i] = target.path.replaceAll(r'\', '/');
          } else if (File(img.filePath).existsSync()) {
            final hasAudio = img.isVideo ? await AudioProbeService.hasAudioStream(img.filePath) : false;
            final startSec = (img.sourceStartOffsetMs / 1000.0).toStringAsFixed(3);
            final List<String> cmdArgs;
            if (img.isVideo) {
              if (hasAudio && !isMuted) {
                cmdArgs = [
                  '-y',
                  '-ss', startSec, '-t', durSec.toStringAsFixed(3),
                  '-i', img.filePath,
                  '-vf', clipVf, '-r', '${config.fps}',
                  '-c:v', 'libx264', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p',
                  '-c:a', 'aac', '-ar', '44100', '-ac', '2',
                  '-af', 'apad=whole_dur=${durSec.toStringAsFixed(3)},aresample=async=1000',
                  '-t', durSec.toStringAsFixed(3),
                  target.path,
                ];
              } else {
                cmdArgs = [
                  '-y',
                  '-ss', startSec, '-t', durSec.toStringAsFixed(3),
                  '-i', img.filePath,
                  '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
                  '-vf', clipVf, '-r', '${config.fps}',
                  '-c:v', 'libx264', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p',
                  '-c:a', 'aac', '-ar', '44100', '-ac', '2',
                  '-t', durSec.toStringAsFixed(3),
                  target.path,
                ];
              }
            } else {
              cmdArgs = [
                '-y',
                '-loop', '1', '-t', durSec.toStringAsFixed(3),
                '-i', img.filePath,
                '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
                '-vf', clipVf, '-r', '${config.fps}',
                '-c:v', 'libx264', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p',
                '-c:a', 'aac', '-ar', '44100', '-ac', '2',
                '-t', durSec.toStringAsFixed(3),
                target.path,
              ];
            }
            await Process.run(ffmpegPath, cmdArgs);
            if (target.existsSync()) normPaths[i] = target.path.replaceAll(r'\', '/');
          }
          completedCount++;
          final pct = 0.02 + (completedCount / exportClips.length) * 0.38;
          onProgress(pct, 'Processing clip $completedCount / ${exportClips.length} (${(pct * 100).toStringAsFixed(0)}%)...');
        }
      }

      if (exportClips.isNotEmpty) {
        await Future.wait(List.generate(poolSize, (_) => worker()));
      }
      if (_isCancelled) { _cleanup(config.outputPath); return false; }

      final buffer = StringBuffer()..writeln('ffconcat version 1.0');
      int currentMs = 0;
      for (int i = 0; i < exportClips.length; i++) {
        final item = exportClips[i];
        if (item.startMs > currentMs) {
          final gapSec = ((item.startMs - currentMs) / 1000.0).toStringAsFixed(3), gapFile = File('${tempDir.path}\\gap_$i.mp4');
          await Process.run(ffmpegPath, [
            '-y',
            '-f', 'lavfi', '-i', 'color=c=black:s=${width}x$height:d=$gapSec:r=${config.fps}',
            '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
            '-c:v', 'libx264', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p',
            '-c:a', 'aac', '-ar', '44100', '-ac', '2',
            '-t', gapSec,
            gapFile.path,
          ]);
          buffer.writeln("file '${gapFile.path.replaceAll(r'\', '/').replaceAll("'", r"'\''")}'");
        }
        buffer.writeln("file '${normPaths[i].replaceAll("'", r"'\''")}'");
        currentMs = item.endMs;
      }
      if (targetDurationMs > currentMs) {
        final tailSec = ((targetDurationMs - currentMs) / 1000.0).toStringAsFixed(3), tailFile = File('${tempDir.path}\\gap_tail.mp4');
        await Process.run(ffmpegPath, [
          '-y',
          '-f', 'lavfi', '-i', 'color=c=black:s=${width}x$height:d=$tailSec:r=${config.fps}',
          '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100',
          '-c:v', 'libx264', '-preset', 'ultrafast', '-pix_fmt', 'yuv420p',
          '-c:a', 'aac', '-ar', '44100', '-ac', '2',
          '-t', tailSec,
          tailFile.path,
        ]);
        buffer.writeln("file '${tailFile.path.replaceAll(r'\', '/').replaceAll("'", r"'\''")}'");
      }
      await concatFile.writeAsString(buffer.toString());

      final totalSec = targetDurationMs / 1000.0;
      final args = <String>['-y', '-f', 'concat', '-safe', '0', '-i', concatFile.path];

      final clips = List<AudioClipItem>.from(activeProject.effectiveAudioClips)
        ..sort((a, b) => a.startTimelineMs.compareTo(b.startTimelineMs));
      final hasSeparateAudio = !activeProject.isAudioMuted && (
        (clips.isNotEmpty && File(clips.first.filePath).existsSync()) ||
        (activeProject.voiceOver != null && File(activeProject.voiceOver!.filePath).existsSync())
      );

      final textFilter = _buildTextFilters(activeProject.textOverlays, height);

      if (hasSeparateAudio) {
        final aConcat = File('${tempDir.path}\\audio_concat.txt'), aBuf = StringBuffer()..writeln('ffconcat version 1.0');
        int curAudioMs = 0;
        for (int i = 0; i < clips.length; i++) {
          final c = clips[i];
          if (!File(c.filePath).existsSync()) continue;
          final gapMs = c.startTimelineMs - curAudioMs;
          if (gapMs > 10) {
            final gapSec = (gapMs / 1000.0).toStringAsFixed(3), silence = File('${tempDir.path}\\silence_$i.wav');
            await Process.run(ffmpegPath, ['-y', '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100', '-t', gapSec, silence.path]);
            aBuf.writeln("file '${silence.path.replaceAll(r'\', '/').replaceAll("'", r"'\''")}'");
          }
          final normAudio = File('${tempDir.path}\\norm_audio_$i.wav');
          final startSec = (c.fileStartOffsetMs / 1000.0).toStringAsFixed(3);
          final durSec = (c.durationMs / 1000.0).toStringAsFixed(3);
          await Process.run(ffmpegPath, [
            '-y',
            '-ss', startSec,
            '-t', durSec,
            '-i', c.filePath,
            '-af', 'volume=${c.volume.toStringAsFixed(2)}',
            '-ar', '44100',
            '-ac', '2',
            normAudio.path,
          ]);
          if (normAudio.existsSync()) {
            aBuf.writeln("file '${normAudio.path.replaceAll(r'\', '/').replaceAll("'", r"'\''")}'");
          }
          curAudioMs = max(curAudioMs, c.endTimelineMs);
        }
        if (targetDurationMs > curAudioMs) {
          final tailGapSec = ((targetDurationMs - curAudioMs) / 1000.0).toStringAsFixed(3);
          final tailSilence = File('${tempDir.path}\\audio_silence_tail.wav');
          await Process.run(ffmpegPath, ['-y', '-f', 'lavfi', '-i', 'anullsrc=channel_layout=stereo:sample_rate=44100', '-t', tailGapSec, tailSilence.path]);
          if (tailSilence.existsSync()) {
            aBuf.writeln("file '${tailSilence.path.replaceAll(r'\', '/').replaceAll("'", r"'\''")}'");
          }
        }
        await aConcat.writeAsString(aBuf.toString());
        args.addAll(['-f', 'concat', '-safe', '0', '-i', aConcat.path]);

        final filterComplex = '[0:v]setsar=1,format=yuv420p$textFilter[vout];[0:a][1:a]amix=inputs=2:duration=first:dropout_transition=2:normalize=0,apad=whole_dur=${totalSec.toStringAsFixed(3)},aresample=async=1000[aout]';
        args.addAll([
          '-filter_complex', filterComplex,
          '-map', '[vout]',
          '-map', '[aout]',
          '-r', '${config.fps}', '-fps_mode', 'cfr',
          '-c:v', config.codec.ffmpegCodec,
          '-crf', '${config.quality.crf}', '-preset', 'fast',
          '-c:a', 'aac', '-b:a', '192k', '-ar', '44100',
          '-t', totalSec.toStringAsFixed(3),
          config.outputPath,
        ]);
      } else {
        final vf = 'setsar=1,format=yuv420p$textFilter';
        args.addAll([
          '-map', '0:v',
          '-map', '0:a',
          '-vf', vf,
          '-r', '${config.fps}', '-fps_mode', 'cfr',
          '-c:v', config.codec.ffmpegCodec,
          '-crf', '${config.quality.crf}', '-preset', 'fast',
          '-c:a', 'aac', '-b:a', '192k', '-ar', '44100',
          '-af', 'apad=whole_dur=${totalSec.toStringAsFixed(3)},aresample=async=1000',
          '-t', totalSec.toStringAsFixed(3),
          config.outputPath,
        ]);
      }

      onProgress(0.40, 'Finalizing video stream with ${config.codec.label}...');
      _activeProcess = await Process.start(ffmpegPath, args);
      final errorLines = <String>[];
      _activeProcess!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        if (errorLines.length > 20) errorLines.removeAt(0);
        errorLines.add(line);
        final match = RegExp(r'time=(\d{2}:\d{2}:\d{2}\.\d+)').firstMatch(line);
        if (match != null && totalSec > 0) {
          final cur = TimeParser.parseToMs(match.group(1)!) ?? 0;
          final pct = 0.40 + (((cur / 1000) / totalSec) * 0.56).clamp(0.0, 0.56);
          onProgress(pct.clamp(0.40, 0.96), 'Rendering: ${match.group(1)} / ${TimeParser.formatStandard(targetDurationMs)} (${(pct * 100).toStringAsFixed(0)}%)');
        }
      });

      final exitCode = await _activeProcess!.exitCode;
      _activeProcess = null;
      if (_isCancelled) { _cleanup(config.outputPath); return false; }
      if (exitCode != 0) throw Exception('FFmpeg failed with code $exitCode: ${errorLines.isNotEmpty ? errorLines.last : ''}');

      onProgress(0.97, 'Verifying exported file...');
      final verified = await _verify(config.outputPath, targetDurationMs);
      if (!verified) throw Exception('Exported file failed duration verification.');
      onProgress(1.0, 'Rendering Complete & Verified!');
      return true;
    } finally {
      try { tempDir.deleteSync(recursive: true); } catch (_) {}
    }
  }

  String _buildTextFilters(List<TextOverlayItem> overlays, int outputHeight) {
    if (overlays.isEmpty) return '';
    final scale = outputHeight / 360.0, buf = StringBuffer();
    for (final t in overlays) {
      final fontPath = _resolveFontPath(t.fontFamily, t.fontFilePath);
      if (fontPath == null) continue;
      final safeFont = fontPath.replaceAll(r'\', '/').replaceAll(':', r'\:');
      final text = t.text.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(":", r"\:").replaceAll('%', r'\%');
      final s = (t.startMs / 1000.0).toStringAsFixed(2), e = (t.endMs / 1000.0).toStringAsFixed(2);
      final size = (t.fontSize * scale * t.scale).round().clamp(10, 400);
      final cHex = (t.textColor.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
      final shHex = (t.shadowColor.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
      final shadow = t.hasShadow ? ':shadowcolor=0x$shHex@0.8:shadowx=${(t.shadowOffsetX * scale).round()}:shadowy=${(t.shadowOffsetY * scale).round()}' : '';
      final bHex = (t.outlineColor.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
      final border = t.hasOutline ? ':bordercolor=0x$bHex:borderw=${(t.outlineWidth * scale).round()}' : '';
      buf.write(",drawtext=fontfile='$safeFont':text='$text':expansion=none:fontsize=$size:fontcolor=0x$cHex$shadow$border:x=(w-text_w)/2+(${t.positionX}*w/2):y=(h-text_h)/2+(${t.positionY}*h/2):enable='between(t,$s,$e)'");
    }
    return buf.toString();
  }

  void _cleanup(String path) { if (File(path).existsSync()) { try { File(path).deleteSync(); } catch (_) {} } }

  Future<bool> _verify(String path, int expectedMs) async {
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() < 1000) return false;
    final ffprobe = AudioProbeService.findFFprobe();
    if (ffprobe == null) return true;
    try {
      final res = await Process.run(ffprobe, ['-v', 'error', '-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', path]);
      if (res.exitCode == 0) { final d = double.tryParse((res.stdout as String).trim()); if (d != null) return ((d * 1000).round() - expectedMs).abs() < 500; }
    } catch (_) {}
    return true;
  }
}
