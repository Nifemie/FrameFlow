import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExportRange {
  final int startMs;
  final int endMs;

  const ExportRange({required this.startMs, required this.endMs});

  int get durationMs => (endMs - startMs).clamp(0, 360000000);
  bool get isValid => endMs > startMs;

  ExportRange copyWith({int? startMs, int? endMs}) => ExportRange(
        startMs: startMs ?? this.startMs,
        endMs: endMs ?? this.endMs,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportRange && startMs == other.startMs && endMs == other.endMs;

  @override
  int get hashCode => Object.hash(startMs, endMs);
}

class ExportRangeState {
  final int? inMs;
  final int? outMs;
  final List<ExportRange> savedRanges;

  const ExportRangeState({
    this.inMs,
    this.outMs,
    this.savedRanges = const [],
  });

  bool get hasRange => inMs != null && outMs != null && outMs! > inMs!;

  ExportRange? get activeRange =>
      hasRange ? ExportRange(startMs: inMs!, endMs: outMs!) : null;

  ExportRangeState copyWith({
    int? inMs,
    int? outMs,
    bool clearIn = false,
    bool clearOut = false,
    List<ExportRange>? savedRanges,
  }) {
    return ExportRangeState(
      inMs: clearIn ? null : (inMs ?? this.inMs),
      outMs: clearOut ? null : (outMs ?? this.outMs),
      savedRanges: savedRanges ?? this.savedRanges,
    );
  }
}

class ExportRangeNotifier extends StateNotifier<ExportRangeState> {
  ExportRangeNotifier() : super(const ExportRangeState());

  void setInPoint(int ms, {int? totalDurationMs}) {
    final clamped = ms.clamp(0, totalDurationMs ?? 360000000);
    final currentOut = state.outMs;
    if (currentOut != null && clamped >= currentOut) {
      // If user moves In past Out, push Out forward or clear Out
      final newOut = totalDurationMs != null
          ? (clamped + 1000).clamp(clamped, totalDurationMs)
          : clamped + 1000;
      if (newOut > clamped) {
        state = state.copyWith(inMs: clamped, outMs: newOut);
      } else {
        state = state.copyWith(inMs: clamped, clearOut: true);
      }
      return;
    }
    state = state.copyWith(inMs: clamped);
  }

  void setOutPoint(int ms, {int? totalDurationMs}) {
    final clamped = ms.clamp(0, totalDurationMs ?? 360000000);
    final currentIn = state.inMs ?? 0;
    if (clamped <= currentIn) {
      final newIn = (clamped - 1000).clamp(0, clamped);
      state = state.copyWith(inMs: newIn, outMs: clamped);
      return;
    }
    state = state.copyWith(inMs: currentIn, outMs: clamped);
  }

  void setRange(int startMs, int endMs) {
    if (endMs <= startMs) return;
    state = state.copyWith(inMs: startMs.clamp(0, 360000000), outMs: endMs.clamp(0, 360000000));
  }

  void clearRange() {
    state = state.copyWith(clearIn: true, clearOut: true);
  }

  void addRange(ExportRange range) {
    if (!range.isValid) return;
    if (state.savedRanges.contains(range)) return;
    state = state.copyWith(savedRanges: [...state.savedRanges, range]);
  }

  void updateSavedRange(int index, ExportRange range) {
    if (index < 0 || index >= state.savedRanges.length) return;
    if (!range.isValid) return;
    final next = List<ExportRange>.from(state.savedRanges);
    next[index] = range;
    state = state.copyWith(savedRanges: next);
  }

  /// Commits the current active [inMs, outMs] range to [savedRanges] and clears
  /// the active markers so the user can immediately mark another range.
  void commitActiveRange() {
    final active = state.activeRange;
    if (active == null) return;
    final next = state.savedRanges.contains(active)
        ? state.savedRanges
        : [...state.savedRanges, active];
    state = state.copyWith(savedRanges: next, clearIn: true, clearOut: true);
  }

  void removeSavedRange(int index) {
    if (index < 0 || index >= state.savedRanges.length) return;
    final next = List<ExportRange>.from(state.savedRanges)..removeAt(index);
    state = state.copyWith(savedRanges: next);
  }

  void clearSavedRanges() {
    state = state.copyWith(savedRanges: const []);
  }
}

final exportRangeProvider = StateNotifierProvider<ExportRangeNotifier, ExportRangeState>((ref) {
  return ExportRangeNotifier();
});
