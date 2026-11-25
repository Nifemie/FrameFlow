import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/features/export/models/export_config.dart';
import 'package:frameflow/models/image_item.dart';
import 'package:frameflow/models/project.dart';
import 'package:frameflow/models/text_overlay_item.dart';
import 'package:frameflow/models/voice_over.dart';
import 'package:frameflow/services/ffmpeg_service.dart';
import 'package:frameflow/services/timing_engine.dart';

void main() {
  group('E2E: FFmpeg Video Export Pipeline with Gaps & Voice-Over', () {
    late Directory tempDir;
    late File imgRed;
    late File imgGreen;
    late File imgBlue;
    late File audioWav;
    late File outputMp4;
    late String ffmpegPath;

    setUpAll(() async {
      tempDir = Directory.systemTemp.createTempSync('e2e_export_test_');
      imgRed = File('${tempDir.path}\\red.png');
      imgGreen = File('${tempDir.path}\\green.png');
      imgBlue = File('${tempDir.path}\\blue.png');
      audioWav = File('${tempDir.path}\\voiceover.wav');
      outputMp4 = File('${tempDir.path}\\output_test.mp4');

      final found = await FFmpegService.findFFmpeg();
      ffmpegPath = found ?? r'C:\Users\USER\Desktop\frameflow\assets\bin\ffmpeg.exe';

      // Generate 3 sample images
      await Process.run(ffmpegPath, ['-y', '-f', 'lavfi', '-i', 'color=c=red:s=320x240:d=1', '-vframes', '1', imgRed.path]);
      await Process.run(ffmpegPath, ['-y', '-f', 'lavfi', '-i', 'color=c=green:s=320x240:d=1', '-vframes', '1', imgGreen.path]);
      await Process.run(ffmpegPath, ['-y', '-f', 'lavfi', '-i', 'color=c=blue:s=320x240:d=1', '-vframes', '1', imgBlue.path]);

      // Generate 8-second test audio tone
      await Process.run(ffmpegPath, ['-y', '-f', 'lavfi', '-i', 'sine=frequency=500:duration=8', audioWav.path]);
    });

    tearDownAll(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('Renders complete video with blank gap and uninterrupted audio', () async {
      // Setup Project: Media 1 (0-2s), Gap (2-4s), Media 2 (4-6s), Media 3 (6-8s)
      final rawImages = [
        ImageItem(id: '1', filePath: imgRed.path, displayName: 'Red', orderIndex: 0, userEndTimestampInput: '00:02'),
        ImageItem(id: '2', filePath: imgGreen.path, displayName: 'Green', orderIndex: 1, userStartTimestampInput: '00:04', userEndTimestampInput: '00:06'),
        ImageItem(id: '3', filePath: imgBlue.path, displayName: 'Blue', orderIndex: 2, userEndTimestampInput: '00:08'),
      ];

      final calculated = TimingEngine.calculateSequence(
        images: rawImages,
        voiceOverDurationMs: 8000,
        snapFinalImageToAudio: true,
      );

      final project = Project(
        id: 'test_project',
        name: 'E2E Export Project',
        images: calculated,
        voiceOver: VoiceOver(
          filePath: audioWav.path,
          fileName: 'voiceover.wav',
          durationMs: 8000,
        ),
        aspectRatio: VideoAspectRatio.ratio16x9,
        resolution: VideoResolution.res720p,
      );

      final config = ExportConfig(
        outputPath: outputMp4.path,
        aspectRatio: VideoAspectRatio.ratio16x9,
        resolution: VideoResolution.res720p,
        format: ExportFormat.mp4,
        codec: VideoCodec.h264,
        quality: QualityPreset.medium,
        fps: 24,
      );

      final service = FFmpegService();
      final doubleList = <double>[];

      final success = await service.renderVideo(
        project: project,
        config: config,
        onProgress: (p, s) => doubleList.add(p),
      );

      expect(success, isTrue);
      expect(outputMp4.existsSync(), isTrue);
      expect(outputMp4.lengthSync(), greaterThan(1000));

      // Verify with ffprobe
      final ffprobe = File(r'C:\Users\USER\Desktop\frameflow\assets\bin\ffprobe.exe');
      if (ffprobe.existsSync()) {
        final probeResult = await Process.run(ffprobe.path, [
          '-v', 'error',
          '-show_entries', 'format=duration:stream=codec_type,width,height',
          '-of', 'default=noprint_wrappers=1',
          outputMp4.path,
        ]);

        final stdout = probeResult.stdout as String;
        expect(stdout, contains('codec_type=video'));
        expect(stdout, contains('codec_type=audio'));
        expect(stdout, contains('width=1280'));
        expect(stdout, contains('height=720'));
      }
    });

    test('Renders complete video with text overlay successfully without crashing', () async {
      final rawImages = [
        ImageItem(id: '1', filePath: imgRed.path, displayName: 'Red', orderIndex: 0, durationMs: 3000),
      ];

      final calculated = TimingEngine.calculateSequence(images: rawImages);
      final textOutput = File('${tempDir.path}\\output_text.mp4');

      final project = Project(
        id: 'text_project',
        name: 'Text Export Project',
        images: calculated,
        textOverlays: [
          const TextOverlayItem(id: 't1', text: 'FrameFlow Title', startMs: 500, durationMs: 2000),
        ],
        aspectRatio: VideoAspectRatio.ratio16x9,
        resolution: VideoResolution.res720p,
      );

      final config = ExportConfig(
        outputPath: textOutput.path,
        aspectRatio: VideoAspectRatio.ratio16x9,
        resolution: VideoResolution.res720p,
        format: ExportFormat.mp4,
        codec: VideoCodec.h264,
        quality: QualityPreset.medium,
        fps: 24,
      );

      final service = FFmpegService();
      final success = await service.renderVideo(
        project: project,
        config: config,
        onProgress: (_, _) {},
      );

      expect(success, isTrue);
      expect(textOutput.existsSync(), isTrue);
      expect(textOutput.lengthSync(), greaterThan(1000));
    });
  });
}
