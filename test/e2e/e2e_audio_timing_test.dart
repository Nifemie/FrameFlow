import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/models/image_item.dart';
import 'package:frameflow/services/audio_probe_service.dart';
import 'package:frameflow/services/timing_engine.dart';

void main() {
  group('E2E: Audio & Voice-Over Timing Pipeline', () {
    late Directory tempDir;
    late File sampleWav;

    setUpAll(() async {
      tempDir = Directory.systemTemp.createTempSync('e2e_audio_test_');
      sampleWav = File('${tempDir.path}\\sample_voice.wav');

      // Generate a clean 6.0 second test tone using bundled ffmpeg
      final ffmpeg = File(r'C:\Users\USER\Desktop\frameflow\assets\bin\ffmpeg.exe');
      if (ffmpeg.existsSync()) {
        await Process.run(ffmpeg.path, [
          '-y',
          '-f', 'lavfi',
          '-i', 'sine=frequency=440:duration=6',
          sampleWav.path,
        ]);
      }
    });

    tearDownAll(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('AudioProbeService extracts precise duration from real audio', () async {
      if (!sampleWav.existsSync()) return;

      final durationMs = await AudioProbeService.getAudioDurationMs(sampleWav.path);
      // Expected 6000ms within +/- 100ms tolerance
      expect(durationMs, greaterThanOrEqualTo(5900));
      expect(durationMs, lessThanOrEqualTo(6100));
    });

    test('Auto-extends final image to match voice-over duration', () {
      final initial = [
        const ImageItem(id: '1', filePath: '1.png', displayName: 'Img 1', orderIndex: 0, userEndTimestampInput: '00:02'),
        const ImageItem(id: '2', filePath: '2.png', displayName: 'Img 2', orderIndex: 1, userEndTimestampInput: '00:04'),
        const ImageItem(id: '3', filePath: '3.png', displayName: 'Img 3', orderIndex: 2), // Default would be 5s
      ];

      // Voice-over is 15 seconds (15000ms)
      final timed = TimingEngine.calculateSequence(
        images: initial,
        voiceOverDurationMs: 15000,
        snapFinalImageToAudio: true,
      );

      expect(timed[0].endMs, equals(2000));
      expect(timed[1].endMs, equals(4000));
      // Final image automatically snaps to voice-over 15000ms
      expect(timed[2].startMs, equals(4000));
      expect(timed[2].endMs, equals(15000));
      expect(timed[2].durationMs, equals(11000));
    });

    test('Removing voice-over resets final image to standard duration', () {
      final initial = [
        const ImageItem(id: '1', filePath: '1.png', displayName: 'Img 1', orderIndex: 0, userEndTimestampInput: '00:03'),
        const ImageItem(id: '2', filePath: '2.png', displayName: 'Img 2', orderIndex: 1),
      ];

      // With voice-over
      final withVoice = TimingEngine.calculateSequence(
        images: initial,
        voiceOverDurationMs: 20000,
        snapFinalImageToAudio: true,
      );
      expect(withVoice.last.endMs, equals(20000));

      // After voice-over removed
      final withoutVoice = TimingEngine.calculateSequence(
        images: initial,
        voiceOverDurationMs: null,
        snapFinalImageToAudio: false,
      );
      expect(withoutVoice.last.startMs, equals(3000));
      expect(withoutVoice.last.endMs, equals(8000)); // Default 5s
    });
  });
}
