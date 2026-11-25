import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/models/image_item.dart';
import 'package:frameflow/models/project.dart';
import 'package:frameflow/models/voice_over.dart';
import 'package:frameflow/services/project_storage_service.dart';
import 'package:frameflow/services/timing_engine.dart';

void main() {
  group('E2E: Project Persistence & Deserialization Workflow', () {
    test('Serializes and deserializes project with gap intervals and voice-over', () {
      final images = [
        const ImageItem(
          id: 'img1',
          filePath: 'C:/media/pic1.jpg',
          displayName: 'Pic 1',
          orderIndex: 0,
          userEndTimestampInput: '00:04',
          fitMode: ImageFitMode.fill,
        ),
        const ImageItem(
          id: 'img2',
          filePath: 'C:/media/pic2.jpg',
          displayName: 'Pic 2',
          orderIndex: 1,
          userStartTimestampInput: '00:08',
          userEndTimestampInput: '00:12',
          fitMode: ImageFitMode.fit,
        ),
      ];

      final calculated = TimingEngine.calculateSequence(
        images: images,
        voiceOverDurationMs: 12000,
        snapFinalImageToAudio: true,
      );

      final originalProject = Project(
        id: 'proj_save_test',
        name: 'My Special Project',
        images: calculated,
        voiceOver: const VoiceOver(
          filePath: 'C:/audio/speech.mp3',
          fileName: 'speech.mp3',
          durationMs: 12000,
        ),
        aspectRatio: VideoAspectRatio.ratio9x16,
        resolution: VideoResolution.res1080p,
        timingMode: TimingMode.manual,
      );

      // Serialize to Map / JSON
      final map = ProjectStorageService.projectToMap(originalProject);
      expect(map['name'], equals('My Special Project'));
      expect(map['aspectRatio'], equals('ratio9x16'));
      expect(map['voiceOver']['durationMs'], equals(12000));

      // Deserialize
      final restored = ProjectStorageService.projectFromMap(map);
      expect(restored.name, equals('My Special Project'));
      expect(restored.aspectRatio, equals(VideoAspectRatio.ratio9x16));
      expect(restored.resolution, equals(VideoResolution.res1080p));
      expect(restored.voiceOver, isNotNull);
      expect(restored.voiceOver!.durationMs, equals(12000));
      expect(restored.images.length, equals(2));

      // Assert gap and timestamps survived serialization intact
      expect(restored.images[0].endMs, equals(4000));
      expect(restored.images[1].startMs, equals(8000));
      expect(restored.images[1].endMs, equals(12000));
      expect(restored.images[1].userStartTimestampInput, equals('00:08'));
    });
  });
}
