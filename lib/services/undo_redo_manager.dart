import '../models/project.dart';

/// Centralized lightweight state-snapshot Undo/Redo manager.
/// Since [Project] is immutable and holds only metadata (paths, timing, configs),
/// storing snapshots is instant and takes negligible memory (<100KB).
class UndoRedoManager {
  static const int maxHistory = 40;

  final List<Project> _undoStack = [];
  final List<Project> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  int get undoCount => _undoStack.length;
  int get redoCount => _redoStack.length;

  /// Records a snapshot of [currentState] before a mutation is applied.
  void recordSnapshot(Project currentState) {
    if (_undoStack.isNotEmpty && identical(_undoStack.last, currentState)) {
      return;
    }
    _undoStack.add(currentState);
    if (_undoStack.length > maxHistory) {
      _undoStack.removeAt(0);
    }
    // Any new action clears the redo branch
    _redoStack.clear();
  }

  /// Reverts to the previous snapshot, placing [currentState] onto the redo stack.
  Project? undo(Project currentState) {
    if (_undoStack.isEmpty) return null;
    final previous = _undoStack.removeLast();
    _redoStack.add(currentState);
    return previous;
  }

  /// Re-applies the undone snapshot, placing [currentState] onto the undo stack.
  Project? redo(Project currentState) {
    if (_redoStack.isEmpty) return null;
    final next = _redoStack.removeLast();
    _undoStack.add(currentState);
    return next;
  }

  /// Clears all undo and redo history (e.g. on new project).
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
