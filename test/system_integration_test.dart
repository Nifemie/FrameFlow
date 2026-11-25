import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/models/image_item.dart';
import 'package:frameflow/models/project.dart';
import 'package:frameflow/models/text_overlay_item.dart';
import 'package:frameflow/services/audio_editing_service.dart';
import 'package:frameflow/services/clip_editing_service.dart';
import 'package:frameflow/services/project_storage_service.dart';
import 'package:frameflow/services/timing_engine.dart';

void main() {
  group('Full System Pipeline Integration Tests', () {
    test('Complete Workflow: Images, Blank Gaps, Ripple Trim, Multi-Audio, Text Titles & Persistence', () async {
      // 1. Initial images setup (26 images simulation)
      final rawImages = List.generate(
        5,
        (i) => ImageItem(
          id: 'img_$i',
          filePath: 'img_$i.jpg',
          displayName: 'Image #${i + 1}',
          orderIndex: i,
        ),
      );

      // 2. Apply timestamps with intentional blank gaps (00:03, 00:04, 00:10 - 00:15, 00:17, 00:22)
      final timestamps = ['00:03', '00:04', '00:10 - 00:15', '00:17', '00:22'];
      final calculatedImages = TimingEngine.applyBulkTimestamps(
        images: rawImages,
        timestampList: timestamps,
        snapFinalImageToAudio: false,
      );

      expect(calculatedImages[0].endMs, 3000);
      expect(calculatedImages[1].endMs, 4000);
      // Blank gap from 4000ms to 10000ms
      expect(calculatedImages[2].startMs, 10000);
      expect(calculatedImages[2].endMs, 15000);
      expect(TimingEngine.findActiveImageIndex(calculatedImages, 6000), -1); // Pure black screen!

      // 3. Ripple Trim Clip: Extend Image #1 from 3000ms to 5000ms (+2000ms)
      // All subsequent clips must shift forward without hiding behind!
      final rippledImages = ClipEditingService.rippleTrimClipEnd(
        images: calculatedImages,
        clipId: 'img_0',
        newEndMs: 5000,
      );

      expect(rippledImages[0].startMs, 0);
      expect(rippledImages[0].endMs, 5000);
      expect(rippledImages[1].startMs, 5000);
      expect(rippledImages[1].endMs, 6000); // Shifted forward!
      expect(rippledImages[2].startMs, 12000); // Blank gap shifted forward!
      expect(rippledImages[2].endMs, 17000);

      // 4. Multi-Audio with gap
      final audioClips = AudioEditingService.appendAudioClip(
        existingClips: const [],
        filePath: 'music_intro.mp3',
        fileName: 'music_intro.mp3',
        durationMs: 4000,
      );
      final multiAudio = AudioEditingService.appendAudioClip(
        existingClips: audioClips,
        filePath: 'voiceover.mp3',
        fileName: 'voiceover.mp3',
        durationMs: 8000,
        customStartMs: 12000, // Starts at Image #3 with silence before!
      );

      expect(multiAudio.length, 2);
      expect(multiAudio[0].endTimelineMs, 4000);
      expect(multiAudio[1].startTimelineMs, 12000);
      expect(multiAudio[1].endTimelineMs, 20000);

      // 5. Add Text Overlays with styles and animation
      const titleText = TextOverlayItem(
        id: 'title_1',
        text: 'FrameFlow Showcase',
        startMs: 0,
        durationMs: 3000,
        fontFamily: 'Montserrat',
        fontSize: 42.0,
        hasShadow: true,
        animationType: TextAnimationType.fadeIn,
      );

      const lowerThirdText = TextOverlayItem(
        id: 'title_2',
        text: 'Featuring Davido',
        startMs: 12000,
        durationMs: 4000,
        fontFamily: 'Roboto',
        fontSize: 32.0,
        positionY: 0.8,
        animationType: TextAnimationType.slideUp,
      );

      // 6. Assemble complete Project
      final project = Project(
        id: 'proj_e2e_full',
        name: 'Full Pipeline Project',
        images: rippledImages,
        audioClips: multiAudio,
        textOverlays: const [titleText, lowerThirdText],
      );

      // Duration: maximum of images (17000ms) and audio (20000ms)
      expect(project.totalImageDurationMs, 24000); // Last image ends at 24000ms
      expect(project.totalAudioDurationMs, 20000);
      expect(project.totalDurationMs, 24000);

      // 7. Save and restore project via ProjectStorageService
      final tempFile = File('${Directory.systemTemp.path}/test_full_project.frameflow');
      try {
        await ProjectStorageService.saveProject(project, tempFile.path);
        expect(tempFile.existsSync(), isTrue);

        final loaded = await ProjectStorageService.loadProject(tempFile.path);
        expect(loaded.id, project.id);
        expect(loaded.images.length, project.images.length);
        expect(loaded.audioClips.length, 2);
        expect(loaded.textOverlays.length, 2);
        expect(loaded.textOverlays[0].text, 'FrameFlow Showcase');
        expect(loaded.textOverlays[1].text, 'Featuring Davido');
        expect(loaded.textOverlays[1].positionY, 0.8);
      } finally {
        if (tempFile.existsSync()) tempFile.deleteSync();
      }
    });
  });
}
