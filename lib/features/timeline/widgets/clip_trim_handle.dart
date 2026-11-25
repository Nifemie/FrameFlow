import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/image_item.dart';
import '../../../providers/project_provider.dart';
import '../services/timeline_zoom_controller.dart';

class ClipTrimHandle extends ConsumerStatefulWidget {
  final ImageItem item;
  final double zoomScale;
  final bool isClipHoveredOrSelected;

  const ClipTrimHandle({
    super.key,
    required this.item,
    required this.zoomScale,
    this.isClipHoveredOrSelected = false,
  });

  @override
  ConsumerState<ClipTrimHandle> createState() => _ClipTrimHandleState();
}

class _ClipTrimHandleState extends ConsumerState<ClipTrimHandle> {
  double _accumulatedDelta = 0;
  int _initialEndMs = 0;
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
          _accumulatedDelta = 0;
          _initialEndMs = widget.item.endMs;
        },
        onHorizontalDragUpdate: (details) {
          _accumulatedDelta += details.delta.dx;
          final deltaMs = ((_accumulatedDelta / pxPerSec) * 1000).round();
          int newEndMs = max(widget.item.startMs + 200, _initialEndMs + deltaMs);

          if (voiceOverDuration != null && (newEndMs - voiceOverDuration).abs() < 250) {
            newEndMs = voiceOverDuration;
          }

          ref.read(projectProvider.notifier).trimClipEnd(
            widget.item.id,
            newEndMs,
            recordUndo: false,
          );
        },
        onHorizontalDragEnd: (_) {
          ref.read(projectProvider.notifier).trimClipEnd(
            widget.item.id,
            widget.item.endMs,
            recordUndo: true,
          );
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
