import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/core/constants/app_constants.dart';
import 'package:frameflow/models/asset_transform.dart';
import 'package:frameflow/models/image_item.dart';
import 'package:frameflow/providers/selection_provider.dart';
import 'package:frameflow/services/alignment_service.dart';
import 'package:frameflow/services/clip_editing_service.dart';

void main() {
  group('Video & Media Import Constants Tests', () {
    test('Recognizes video file formats', () {
      expect(AppConstants.isVideoFile('video.mp4'), isTrue);
      expect(AppConstants.isVideoFile('clip.MOV'), isTrue);
      expect(AppConstants.isVideoFile('movie.webm'), isTrue);
      expect(AppConstants.isVideoFile('capture.avi'), isTrue);
      expect(AppConstants.isVideoFile('stream.mkv'), isTrue);
      expect(AppConstants.isVideoFile('photo.png'), isFalse);
    });

    test('Recognizes image and audio file formats', () {
      expect(AppConstants.isImageFile('photo.jpg'), isTrue);
      expect(AppConstants.isImageFile('pic.png'), isTrue);
      expect(AppConstants.isAudioFile('narration.mp3'), isTrue);
      expect(AppConstants.isAudioFile('track.wav'), isTrue);
    });
  });

  group('Gap-Preserving Clip Deletion Tests', () {
    test('Deleting middle clip leaves an empty gap and preserves timing of adjacent clips', () {
      const clipA = ImageItem(
        id: 'clipA', filePath: 'a.png', displayName: 'Clip A', orderIndex: 0,
        startMs: 0, endMs: 5000, durationMs: 5000, userStartTimestampInput: '0.00', userEndTimestampInput: '5.00',
      );
      const clipB = ImageItem(
        id: 'clipB', filePath: 'b.png', displayName: 'Clip B', orderIndex: 1,
        startMs: 5000, endMs: 10000, durationMs: 5000, userStartTimestampInput: '5.00', userEndTimestampInput: '10.00',
      );
      const clipC = ImageItem(
        id: 'clipC', filePath: 'c.png', displayName: 'Clip C', orderIndex: 2,
        startMs: 10000, endMs: 15000, durationMs: 5000, userStartTimestampInput: '10.00', userEndTimestampInput: '15.00',
      );

      final initial = [clipA, clipB, clipC];
      final result = ClipEditingService.deleteClipPreservingGaps(
        images: initial,
        clipIdsToDelete: {'clipB'},
      );

      expect(result.length, equals(2));
      expect(result.first.id, equals('clipA'));
      expect(result.first.startMs, equals(0));
      expect(result.first.endMs, equals(5000));

      // Clip C must remain at 10000 to 15000 — NOT rippled back to 5000!
      expect(result.last.id, equals('clipC'));
      expect(result.last.startMs, equals(10000));
      expect(result.last.endMs, equals(15000));
    });

    test('Deleting multiple clips leaves multiple respective gaps', () {
      const clipA = ImageItem(
        id: 'clipA', filePath: 'a.png', displayName: 'Clip A', orderIndex: 0,
        startMs: 0, endMs: 4000, durationMs: 4000, userStartTimestampInput: '0.00', userEndTimestampInput: '4.00',
      );
      const clipB = ImageItem(
        id: 'clipB', filePath: 'b.png', displayName: 'Clip B', orderIndex: 1,
        startMs: 4000, endMs: 8000, durationMs: 4000, userStartTimestampInput: '4.00', userEndTimestampInput: '8.00',
      );
      const clipC = ImageItem(
        id: 'clipC', filePath: 'c.png', displayName: 'Clip C', orderIndex: 2,
        startMs: 8000, endMs: 12000, durationMs: 4000, userStartTimestampInput: '8.00', userEndTimestampInput: '12.00',
      );
      const clipD = ImageItem(
        id: 'clipD', filePath: 'd.png', displayName: 'Clip D', orderIndex: 3,
        startMs: 12000, endMs: 16000, durationMs: 4000, userStartTimestampInput: '12.00', userEndTimestampInput: '16.00',
      );

      final result = ClipEditingService.deleteClipPreservingGaps(
        images: [clipA, clipB, clipC, clipD],
        clipIdsToDelete: {'clipB', 'clipD'},
      );

      expect(result.length, equals(2));
      expect(result[0].id, equals('clipA'));
      expect(result[0].startMs, equals(0));
      expect(result[0].endMs, equals(4000));

      expect(result[1].id, equals('clipC'));
      expect(result[1].startMs, equals(8000));
      expect(result[1].endMs, equals(12000));
    });
  });

  group('Alignment & Distribution Service Tests', () {
    test('Align single asset to canvas positions', () {
      const transform = AssetTransform(positionX: 0.2, positionY: 0.4);

      final left = AlignmentService.alignSingle(transform, AlignmentType.left);
      expect(left.positionX, equals(-0.75));

      final centerH = AlignmentService.alignSingle(transform, AlignmentType.horizontalCenter);
      expect(centerH.positionX, equals(0.0));

      final right = AlignmentService.alignSingle(transform, AlignmentType.right);
      expect(right.positionX, equals(0.75));

      final top = AlignmentService.alignSingle(transform, AlignmentType.top);
      expect(top.positionY, equals(-0.75));

      final centerV = AlignmentService.alignSingle(transform, AlignmentType.verticalCenter);
      expect(centerV.positionY, equals(0.0));

      final bottom = AlignmentService.alignSingle(transform, AlignmentType.bottom);
      expect(bottom.positionY, equals(0.75));

      final centerCanvas = AlignmentService.alignSingle(transform, AlignmentType.centerCanvas);
      expect(centerCanvas.positionX, equals(0.0));
      expect(centerCanvas.positionY, equals(0.0));
    });

    test('Align multiple assets to common edge', () {
      const item1 = ImageItem(
        id: 'item1', filePath: '1.png', displayName: 'Item 1', orderIndex: 0,
        transform: AssetTransform(positionX: -0.5, positionY: -0.2),
      );
      const item2 = ImageItem(
        id: 'item2', filePath: '2.png', displayName: 'Item 2', orderIndex: 1,
        transform: AssetTransform(positionX: 0.3, positionY: 0.4),
      );

      final alignedLeft = AlignmentService.alignMultiple(
        allImages: [item1, item2],
        targetIds: {'item1', 'item2'},
        type: AlignmentType.left,
      );

      // Both should share minX = -0.5
      expect(alignedLeft[0].transform.positionX, equals(-0.5));
      expect(alignedLeft[1].transform.positionX, equals(-0.5));

      final alignedRight = AlignmentService.alignMultiple(
        allImages: [item1, item2],
        targetIds: {'item1', 'item2'},
        type: AlignmentType.right,
      );

      // Both should share maxX = 0.3
      expect(alignedRight[0].transform.positionX, equals(0.3));
      expect(alignedRight[1].transform.positionX, equals(0.3));
    });

    test('Match Width and Match Height across selected assets', () {
      const item1 = ImageItem(
        id: 'item1', filePath: '1.png', displayName: 'Item 1', orderIndex: 0,
        transform: AssetTransform(scaleX: 1.5, scaleY: 1.2),
      );
      const item2 = ImageItem(
        id: 'item2', filePath: '2.png', displayName: 'Item 2', orderIndex: 1,
        transform: AssetTransform(scaleX: 0.8, scaleY: 0.6),
      );

      final matchedWidth = AlignmentService.alignMultiple(
        allImages: [item1, item2],
        targetIds: {'item1', 'item2'},
        type: AlignmentType.matchWidth,
      );

      expect(matchedWidth[0].transform.scaleX, equals(1.5));
      expect(matchedWidth[1].transform.scaleX, equals(1.5));
    });
  });

  group('Workspace Focus Mode Tests', () {
    test('Focus modes have expected values', () {
      expect(WorkspaceFocusMode.values.contains(WorkspaceFocusMode.normal), isTrue);
      expect(WorkspaceFocusMode.values.contains(WorkspaceFocusMode.timeline), isTrue);
      expect(WorkspaceFocusMode.values.contains(WorkspaceFocusMode.preview), isTrue);
      expect(WorkspaceFocusMode.values.contains(WorkspaceFocusMode.media), isTrue);
    });
  });
}
