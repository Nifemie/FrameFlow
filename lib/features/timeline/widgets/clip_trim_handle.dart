import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/image_item.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../services/timeline_arrangement_service.dart';
import '../services/timeline_zoom_controller.dart';

class ClipTrimHandle extends ConsumerStatefulWidget {
  final ImageItem item;
  final double zoomScale;
  final bool isClipHoveredOrSelected;
  final bool isLeftEdge;

  const ClipTrimHandle({
    super.key,
    required this.item,
    required this.zoomScale,
    this.isClipHoveredOrSelected = false,
    this.isLeftEdge = false,
  });

  @override
  ConsumerState<ClipTrimHandle> createState() => _ClipTrimHandleState();
}

class _ClipTrimHandleState extends ConsumerState<ClipTrimHandle> {
  double _accumulatedDelta = 0;
  int _initialEdgeMs = 0;
  bool _isHandleHovered = false;

  @override
  Widget build(BuildContext context) {
    final pxPerSec = TimelineZoomController.pxPerSec(widget.zoomScale);
    final voiceOverDuration = ref.watch(projectProvider.select((p) => p.voiceOver?.durationMs));
    final showGrip = _isHandleHovered || widget.isClipHoveredOrSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHandleHovered = true),
      onExit: (_) => setState(() => _isHandleHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          ref.read(projectProvider.notifier).recordSnapshot();
          _accumulatedDelta = 0;
          _initialEdgeMs = widget.isLeftEdge ? widget.item.startMs : widget.item.endMs;
        },
        onHorizontalDragUpdate: (details) {
          _accumulatedDelta += details.delta.dx;
          final deltaMs = ((_accumulatedDelta / pxPerSec) * 1000).round();
          int newEdgeMs = widget.isLeftEdge
              ? max(0, min(widget.item.endMs - 200, _initialEdgeMs + deltaMs))
              : max(widget.item.startMs + 200, _initialEdgeMs + deltaMs);

          final snapOn = ref.read(snappingEnabledProvider);
          if (snapOn) {
            final project = ref.read(projectProvider);
            final targets = <int>[
              0,
              ref.read(playheadPositionProvider),
              ?voiceOverDuration,
              ...project.markers.map((m) => m.timestampMs),
              ...project.images.where((i) => i.id != widget.item.id).expand((i) => [i.startMs, i.endMs]),
              ...project.textOverlays.expand((t) => [t.startMs, t.endMs]),
            ];
            final (snapped, line) = TimelineArrangementService.snapToTargets(
              targetMs: newEdgeMs,
              targets: targets,
              pxPerSec: pxPerSec,
              enabled: true,
            );
            newEdgeMs = widget.isLeftEdge
                ? max(0, min(widget.item.endMs - 200, snapped))
                : max(widget.item.startMs + 200, snapped);
            ref.read(activeSnapLineMsProvider.notifier).state = line;
          } else {
            ref.read(activeSnapLineMsProvider.notifier).state = null;
          }

          if (widget.isLeftEdge) {
            ref.read(projectProvider.notifier).trimClipStart(
              widget.item.id,
              newEdgeMs,
              recordUndo: false,
            );
          } else {
            ref.read(projectProvider.notifier).trimClipEnd(
              widget.item.id,
              newEdgeMs,
              recordUndo: false,
            );
          }
        },
        onHorizontalDragEnd: (_) {
          ref.read(activeSnapLineMsProvider.notifier).state = null;
        },
        child: Container(
          width: 12,
          color: Colors.transparent,
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: showGrip ? 0.9 : 0.0,
              child: Container(
                width: 3,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(1.5),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 2),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
