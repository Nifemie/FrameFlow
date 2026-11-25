import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/models/image_item.dart';
import 'package:frameflow/services/clip_editing_service.dart';
import 'package:frameflow/services/timing_engine.dart';

void main() {
  group('E2E: Media Import & Management Workflow', () {
    test('Batch adding images calculates sequential 5s default timing', () {
      final initialImages = List.generate(
        4,
        (i) => ImageItem(
          id: 'img_$i',
          filePath: 'C:/assets/photo_$i.png',
          displayName: 'photo_$i.png',
          orderIndex: i,
        ),
      );

      final timed = TimingEngine.calculateSequence(
        images: initialImages,
        snapFinalImageToAudio: false,
      );

      expect(timed.length, equals(4));
      expect(timed[0].startMs, equals(0));
      expect(timed[0].endMs, equals(5000));
      expect(timed[1].startMs, equals(5000));
      expect(timed[1].endMs, equals(10000));
      expect(timed[2].startMs, equals(10000));
      expect(timed[2].endMs, equals(15000));
      expect(timed[3].startMs, equals(15000));
      expect(timed[3].endMs, equals(20000));
    });

    test('Reordering images shifts timeline boundaries without corruption', () {
      final images = [
        const ImageItem(id: 'a', filePath: 'a.png', displayName: 'A', orderIndex: 0, userEndTimestampInput: '00:03'),
        const ImageItem(id: 'b', filePath: 'b.png', displayName: 'B', orderIndex: 1, userEndTimestampInput: '00:08'),
        const ImageItem(id: 'c', filePath: 'c.png', displayName: 'C', orderIndex: 2, userEndTimestampInput: '00:15'),
      ];

      final calculated = TimingEngine.calculateSequence(images: images, snapFinalImageToAudio: false);
      expect(calculated[0].durationMs, equals(3000));
      expect(calculated[1].durationMs, equals(5000));
      expect(calculated[2].durationMs, equals(7000));

      // Move C to position 0 (reorder)
      final reordered = [images[2], images[0], images[1]];
      final afterReorder = TimingEngine.calculateSequence(images: reordered, snapFinalImageToAudio: false);

      expect(afterReorder[0].displayName, equals('C'));
      expect(afterReorder[0].startMs, equals(0));
      expect(afterReorder[1].displayName, equals('A'));
      expect(afterReorder[2].displayName, equals('B'));
    });

    test('Deleting an image ripples subsequent image intervals', () {
      final images = [
        const ImageItem(id: '1', filePath: '1.png', displayName: '1', orderIndex: 0, userEndTimestampInput: '00:04'),
        const ImageItem(id: '2', filePath: '2.png', displayName: '2', orderIndex: 1, userEndTimestampInput: '00:07'),
        const ImageItem(id: '3', filePath: '3.png', displayName: '3', orderIndex: 2, userEndTimestampInput: '00:12'),
      ];

      final calculated = TimingEngine.calculateSequence(images: images, snapFinalImageToAudio: false);
      final remaining = ClipEditingService.deleteClip(images: calculated, clipId: '2');

      expect(remaining.length, equals(2));
      expect(remaining[0].displayName, equals('1'));
      expect(remaining[0].endMs, equals(4000));
      // Clip 3 ripples backward to start where clip 1 ended (4000ms) with user timestamp at 12000ms
      expect(remaining[1].displayName, equals('3'));
      expect(remaining[1].startMs, equals(4000));
      expect(remaining[1].durationMs, equals(8000));
      expect(remaining[1].endMs, equals(12000));
    });
  });
}
