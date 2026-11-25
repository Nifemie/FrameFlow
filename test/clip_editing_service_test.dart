import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/models/image_item.dart';
import 'package:frameflow/services/clip_editing_service.dart';
import 'package:frameflow/services/timing_engine.dart';

void main() {
  group('ClipEditingService Tests', () {
    late List<ImageItem> sampleImages;

    setUp(() {
      sampleImages = TimingEngine.calculateSequence(
        images: const [
          ImageItem(id: 'img1', filePath: 'a.jpg', displayName: 'Image 01', orderIndex: 0),
          ImageItem(id: 'img2', filePath: 'b.jpg', displayName: 'Image 02', orderIndex: 1),
        ],
      );
      // img1: 0 - 5000ms
      // img2: 5000 - 10000ms
    });

    test('Splits clip into two distinct clips at exact playhead', () {
      final result = ClipEditingService.splitClipAt(
        images: sampleImages,
        playheadMs: 2500, // exact midpoint of Image 01
      );

      expect(result, isNotNull);
      expect(result!.length, 3);

      final partA = result[0];
      final partB = result[1];
      final img2 = result[2];

      expect(partA.id, 'img1');
      expect(partA.displayName, 'Image 01 (Part 1)');
      expect(partA.startMs, 0);
      expect(partA.endMs, 2500);
      expect(partA.durationMs, 2500);

      expect(partB.id, isNot('img1')); // New unique ID
      expect(partB.filePath, 'a.jpg'); // Same image asset
      expect(partB.displayName, 'Image 01 (Part 2)');
      expect(partB.startMs, 2500);
      expect(partB.endMs, 5000);
      expect(partB.durationMs, 2500);

      expect(img2.startMs, 5000);
      expect(img2.endMs, 10000);
    });

    test('Rejects splitting within 100ms of boundary', () {
      final tooEarly = ClipEditingService.splitClipAt(
        images: sampleImages,
        playheadMs: 50, // within 100ms of start
      );
      expect(tooEarly, isNull);

      final tooLate = ClipEditingService.splitClipAt(
        images: sampleImages,
        playheadMs: 4950, // within 100ms of end
      );
      expect(tooLate, isNull);
    });

    test('Duplicates clip immediately after original with copy name', () {
      final result = ClipEditingService.duplicateClip(
        images: sampleImages,
        clipId: 'img1',
      );

      expect(result.length, 3);
      expect(result[0].id, 'img1');
      expect(result[1].displayName, 'Image 01 (Copy)');
      expect(result[1].filePath, 'a.jpg');
      expect(result[2].id, 'img2');
    });

    test('Deletes clip and ripples subsequent clips backward', () {
      final result = ClipEditingService.deleteClip(
        images: sampleImages,
        clipId: 'img1',
        ripple: true,
      );

      expect(result.length, 1);
      final remaining = result[0];
      expect(remaining.id, 'img2');
      expect(remaining.startMs, 0); // Rippled back to 0
      expect(remaining.endMs, 5000);
    });

    test('rippleTrimClipEnd shifts subsequent clips forward when extending without hiding them', () {
      // img1: 0 to 5000ms (duration 5000ms)
      // img2: 5000 to 10000ms (duration 5000ms)
      // Extend img1 to 8000ms (+3000ms):
      final result = ClipEditingService.rippleTrimClipEnd(
        images: sampleImages,
        clipId: 'img1',
        newEndMs: 8000,
      );

      expect(result.length, 2);
      expect(result[0].startMs, 0);
      expect(result[0].endMs, 8000);
      expect(result[0].durationMs, 8000);

      // img2 must shift forward to start at 8000ms and keep its 5000ms duration!
      expect(result[1].startMs, 8000);
      expect(result[1].endMs, 13000);
      expect(result[1].durationMs, 5000);
    });

    test('rippleTrimClipEnd shifts subsequent clips backward when shrinking', () {
      // Shrink img1 from 5000ms to 2000ms (-3000ms):
      final result = ClipEditingService.rippleTrimClipEnd(
        images: sampleImages,
        clipId: 'img1',
        newEndMs: 2000,
      );

      expect(result.length, 2);
      expect(result[0].startMs, 0);
      expect(result[0].endMs, 2000);
      expect(result[0].durationMs, 2000);

      // img2 must shift backward to start at 2000ms and keep its 5000ms duration!
      expect(result[1].startMs, 2000);
      expect(result[1].endMs, 7000);
      expect(result[1].durationMs, 5000);
    });

    test('Video splitting correctly calculates sourceStartOffsetMs for successive splits', () {
      final videoClips = TimingEngine.calculateSequence(
        images: const [
          ImageItem(
            id: 'vid1',
            filePath: 'movie.mp4',
            displayName: 'movie.mp4',
            orderIndex: 0,
            durationMs: 18000,
            sourceDurationMs: 18000,
            sourceStartOffsetMs: 0,
          ),
        ],
      );

      // Split 1: at 5000ms
      final split1 = ClipEditingService.splitClipAt(
        images: videoClips,
        playheadMs: 5000,
      );

      expect(split1, isNotNull);
      expect(split1!.length, 2);
      final partA = split1[0];
      final partB = split1[1];

      expect(partA.startMs, 0);
      expect(partA.endMs, 5000);
      expect(partA.durationMs, 5000);
      expect(partA.sourceStartOffsetMs, 0);

      expect(partB.startMs, 5000);
      expect(partB.endMs, 18000);
      expect(partB.durationMs, 13000);
      expect(partB.sourceStartOffsetMs, 5000); // starts 5s into movie.mp4

      // Split 2: split partB at 12000ms (7000ms into partB)
      final split2 = ClipEditingService.splitClipAt(
        images: split1,
        playheadMs: 12000,
      );

      expect(split2, isNotNull);
      expect(split2!.length, 3);
      final pA = split2[0];
      final pB1 = split2[1];
      final pB2 = split2[2];

      expect(pA.sourceStartOffsetMs, 0);
      expect(pB1.startMs, 5000);
      expect(pB1.endMs, 12000);
      expect(pB1.sourceStartOffsetMs, 5000);

      expect(pB2.startMs, 12000);
      expect(pB2.endMs, 18000);
      expect(pB2.sourceStartOffsetMs, 12000); // 5000 + (12000 - 5000) = 12000ms into source!
    });
  });
}
