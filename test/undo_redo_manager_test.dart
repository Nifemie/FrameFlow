import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/models/image_item.dart';
import 'package:frameflow/models/project.dart';
import 'package:frameflow/services/undo_redo_manager.dart';

void main() {
  group('UndoRedoManager Tests', () {
    late UndoRedoManager manager;
    late Project p0;
    late Project p1;
    late Project p2;

    setUp(() {
      manager = UndoRedoManager();
      p0 = const Project(id: '1', name: 'Initial');
      p1 = const Project(id: '1', name: 'Step 1', images: [
        ImageItem(id: 'a', filePath: 'a.jpg', displayName: 'A', orderIndex: 0),
      ]);
      p2 = const Project(id: '1', name: 'Step 2', images: [
        ImageItem(id: 'a', filePath: 'a.jpg', displayName: 'A', orderIndex: 0),
        ImageItem(id: 'b', filePath: 'b.jpg', displayName: 'B', orderIndex: 1),
      ]);
    });

    test('Undo reverts through recorded states', () {
      manager.recordSnapshot(p0);
      manager.recordSnapshot(p1);

      expect(manager.canUndo, isTrue);
      expect(manager.canRedo, isFalse);

      final undone1 = manager.undo(p2);
      expect(undone1?.name, 'Step 1');
      expect(manager.canRedo, isTrue);

      final undone2 = manager.undo(undone1!);
      expect(undone2?.name, 'Initial');

      final undone3 = manager.undo(undone2!);
      expect(undone3, isNull);
    });

    test('Redo steps forward after undo', () {
      manager.recordSnapshot(p0);
      manager.recordSnapshot(p1);

      final undone1 = manager.undo(p2);
      expect(undone1?.name, 'Step 1');

      final redone = manager.redo(undone1!);
      expect(redone?.name, 'Step 2');
      expect(manager.canRedo, isFalse);
    });

    test('New action invalidates redo stack', () {
      manager.recordSnapshot(p0);
      manager.recordSnapshot(p1);
      manager.undo(p2);
      expect(manager.canRedo, isTrue);

      // New action performed
      manager.recordSnapshot(p1);
      expect(manager.canRedo, isFalse);
    });
  });
}
