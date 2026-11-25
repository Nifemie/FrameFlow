import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/text_overlay_item.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';

class TextTimelineItem extends ConsumerStatefulWidget {
  final TextOverlayItem item;
  final double pxPerSec;
  final bool isSelected;
  final List<int> boundaries;

  const TextTimelineItem({
    super.key,
    required this.item,
    required this.pxPerSec,
    required this.isSelected,
    required this.boundaries,
  });

  @override
  ConsumerState<TextTimelineItem> createState() => _TextTimelineItemState();
}

class _TextTimelineItemState extends ConsumerState<TextTimelineItem> {
  double _accumulatedDelta = 0.0;
  int _dragStartMs = 0;
  int _dragDurationMs = 0;

  int _snap(int target, double thresholdMs) {
    for (final b in widget.boundaries) {
      if ((target - b).abs() <= thresholdMs) return b;
    }
    return target;
  }

  void _onMoveStart() {
    ref.read(projectProvider.notifier).recordSnapshot();
    _accumulatedDelta = 0.0;
    _dragStartMs = widget.item.startMs;
  }

  void _onMoveUpdate(DragUpdateDetails d) {
    _accumulatedDelta += d.delta.dx;
    final deltaMs = ((_accumulatedDelta / widget.pxPerSec) * 1000).round();
    final newStart = max(0, _dragStartMs + deltaMs);
    ref.read(projectProvider.notifier).trimTextOverlay(widget.item.id, startMs: newStart, recordUndo: false);
  }

  void _onResizeLeftStart() {
    ref.read(projectProvider.notifier).recordSnapshot();
    _accumulatedDelta = 0.0;
    _dragStartMs = widget.item.startMs;
    _dragDurationMs = widget.item.durationMs;
  }

  void _onResizeLeftUpdate(DragUpdateDetails d) {
    _accumulatedDelta += d.delta.dx;
    final deltaMs = ((_accumulatedDelta / widget.pxPerSec) * 1000).round();
    final maxEnd = _dragStartMs + _dragDurationMs;
    var candStart = (_dragStartMs + deltaMs).clamp(0, maxEnd - 200);
    if (d.delta.dx.abs() < 3.5) candStart = _snap(candStart, 6.0 / widget.pxPerSec * 1000);
    ref.read(projectProvider.notifier).trimTextOverlay(widget.item.id, startMs: candStart, durationMs: maxEnd - candStart, recordUndo: false);
  }

  void _onResizeRightStart() {
    ref.read(projectProvider.notifier).recordSnapshot();
    _accumulatedDelta = 0.0;
    _dragDurationMs = widget.item.durationMs;
  }

  void _onResizeRightUpdate(DragUpdateDetails d) {
    _accumulatedDelta += d.delta.dx;
    final deltaMs = ((_accumulatedDelta / widget.pxPerSec) * 1000).round();
    var candDur = max(200, _dragDurationMs + deltaMs);
    if (d.delta.dx.abs() < 3.5) {
      final candEnd = _snap(widget.item.startMs + candDur, 6.0 / widget.pxPerSec * 1000);
      candDur = max(200, candEnd - widget.item.startMs);
    }
    ref.read(projectProvider.notifier).trimTextOverlay(widget.item.id, durationMs: candDur, recordUndo: false);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final left = (item.startMs / 1000) * widget.pxPerSec;
    final width = max(40.0, (item.durationMs / 1000) * widget.pxPerSec);
    final isSelected = widget.isSelected;

    return Positioned(
      left: left, top: 1, bottom: 1, width: width,
      child: Container(
        margin: const EdgeInsets.only(right: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentOrange.withValues(alpha: 0.35) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? AppColors.accentOrange : Colors.amber.withValues(alpha: 0.6), width: isSelected ? 1.5 : 1.0),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              left: 14, right: 14,
              child: GestureDetector(
                onTap: () {
                  ref.read(selectedTextOverlayIdProvider.notifier).state = item.id;
                  ref.read(selectedImageIdProvider.notifier).state = null;
                },
                onHorizontalDragStart: (_) => _onMoveStart(),
                onHorizontalDragUpdate: _onMoveUpdate,
                child: Container(
                  color: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.title, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      Expanded(child: Text(item.text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis)),
                      Text('${(item.durationMs / 1000).toStringAsFixed(1)}s', style: const TextStyle(fontSize: 8.5, color: Colors.amberAccent)),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0, top: 0, bottom: 0, width: 14,
              child: Tooltip(
                message: 'Drag to adjust start time',
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) => _onResizeLeftStart(),
                    onHorizontalDragUpdate: _onResizeLeftUpdate,
                    child: Container(
                      alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 3),
                      child: Container(width: 3, height: 16, decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(1.5))),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0, top: 0, bottom: 0, width: 14,
              child: Tooltip(
                message: 'Drag to expand/shrink across timeline',
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeLeftRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) => _onResizeRightStart(),
                    onHorizontalDragUpdate: _onResizeRightUpdate,
                    child: Container(
                      alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 3),
                      child: Container(width: 3, height: 16, decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(1.5))),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}