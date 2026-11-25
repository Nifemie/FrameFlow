import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/models/image_item.dart';
import 'package:frameflow/models/project.dart';
import 'package:frameflow/services/clip_editing_service.dart';
import 'package:frameflow/services/timing_engine.dart';
import 'package:frameflow/services/undo_redo_manager.dart';

void main() {
  group('E2E: Gap Handling, Split/Duplicate/Delete & Undo/Redo Workflow', () {
    test('Option 1: Blank gap returns -1 (black screen) while timeline advances', () {
      final initial = [
        const ImageItem(id: '1', filePath: '1.jpg', displayName: '01 Media', orderIndex: 0, userEndTimestampInput: '00:04'),
        const ImageItem(id: '2', filePath: '2.jpg', displayName: '02 Media', orderIndex: 1, userEndTimestampInput: '00:06'),
        const ImageItem(id: '3', filePath: '3.jpg', displayName: '03 Media', orderIndex: 2, userStartTimestampInput: '00:10', userEndTimestampInput: '00:14'),
      ];

      final calculated = TimingEngine.calculateSequence(images: initial, snapFinalImageToAudio: false);

      expect(calculated[0].startMs, equals(0));
      expect(calculated[0].endMs, equals(4000));
      expect(calculated[1].startMs, equals(4000));
      expect(calculated[1].endMs, equals(6000));
      expect(calculated[2].startMs, equals(10000));
      expect(calculated[2].endMs, equals(14000));

      // At 5000ms -> Media 2 is active
      expect(TimingEngine.findActiveImageIndex(calculated, 5000), equals(1));
      // At 7000ms and 9000ms -> In blank gap, returns -1 (Preview renders black screen)
      expect(TimingEngine.findActiveImageIndex(calculated, 7000), equals(-1));
      expect(TimingEngine.findActiveImageIndex(calculated, 9000), equals(-1));
      // At 10500ms -> Media 3 is active
      expect(TimingEngine.findActiveImageIndex(calculated, 10500), equals(2));
    });

    test('Split clip at playhead creates two distinct clips', () {
      final images = [
        const ImageItem(id: '1', filePath: '1.jpg', displayName: 'Clip 1', orderIndex: 0, startMs: 0, endMs: 6000),
      ];

      final splitResult = ClipEditingService.splitClipAt(
        images: images,
        playheadMs: 2500,
      );

      expect(splitResult, isNotNull);
      expect(splitResult!.length, equals(2));
      expect(splitResult[0].endMs, equals(2500));
      expect(splitResult[1].startMs, equals(2500));
      expect(splitResult[1].endMs, equals(6000));
      expect(splitResult[1].id, isNot(equals(splitResult[0].id)));
    });

    test('Duplicate clip and delete clip ripple intervals correctly', () {
      final images = [
        const ImageItem(id: '1', filePath: '1.jpg', displayName: 'Clip 1', orderIndex: 0, userEndTimestampInput: '00:05'),
      ];
      final timed = TimingEngine.calculateSequence(images: images, snapFinalImageToAudio: false);

      // Duplicate
      final duplicated = ClipEditingService.duplicateClip(images: timed, clipId: '1');
      expect(duplicated.length, equals(2));
      expect(duplicated[1].displayName, equals('Clip 1 (Copy)'));
      expect(duplicated[1].startMs, equals(5000));
      expect(duplicated[1].endMs, equals(10000));

      // Delete the duplicate
      final afterDelete = ClipEditingService.deleteClip(images: duplicated, clipId: duplicated[1].id);
      expect(afterDelete.length, equals(1));
      expect(afterDelete[0].id, equals('1'));
      expect(afterDelete[0].endMs, equals(5000));
    });

    test('Undo and Redo manager cleanly steps through history', () {
      final manager = UndoRedoManager();
      const p1 = Project(id: '1', name: 'P1');
      const p2 = Project(id: '2', name: 'P2');
      const p3 = Project(id: '3', name: 'P3');
      manager.recordSnapshot(p1);
      manager.recordSnapshot(p2);

      expect(manager.canUndo, isTrue);
      expect(manager.undo(p3)?.id, equals('2'));
      expect(manager.undo(p2)?.id, equals('1'));
      expect(manager.canUndo, isFalse);

      expect(manager.canRedo, isTrue);
      expect(manager.redo(p1)?.id, equals('2'));
      expect(manager.redo(p2)?.id, equals('3'));
      expect(manager.canRedo, isFalse);
    });
  });
}
