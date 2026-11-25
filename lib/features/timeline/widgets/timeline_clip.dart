import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/image_item.dart';
import '../../../providers/project_provider.dart';
import '../../../services/video_metadata_service.dart';
import '../services/timeline_zoom_controller.dart';
import 'asset_context_menus.dart';
import 'clip_insert_button.dart';
import 'clip_trim_handle.dart';

class TimelineClip extends ConsumerStatefulWidget {
  final ImageItem item;
  final bool isSelected;
  final double zoomScale;
  final VoidCallback onTap;

  const TimelineClip({super.key, required this.item, required this.isSelected, required this.zoomScale, required this.onTap});

  @override
  ConsumerState<TimelineClip> createState() => _TimelineClipState();
}

class _TimelineClipState extends ConsumerState<TimelineClip> {
  bool _isHovered = false;
  int _dropSide = 0; // 0: none, 1: before, 2: swap, 3: after

  void _swapWith(int targetOrder) {
    final allImages = ref.read(projectProvider).imagesForTrack(widget.item.trackId);
    if (targetOrder < 0 || targetOrder >= allImages.length) return;
    ref.read(projectProvider.notifier).swapImageClips(widget.item.id, allImages[targetOrder].id);
  }

  Widget _buildMediaThumbnail(ImageItem item) {
    if (item.isVideo) {
      final thumbPath = VideoMetadataService.getCachedThumbnail(item.filePath);
      if (thumbPath != null && File(thumbPath).existsSync()) {
        return Image.file(
          File(thumbPath),
          cacheWidth: 120,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildVideoFallback(),
        );
      }
      VideoMetadataService.getThumbnailPath(item.filePath).then((p) {
        if (p != null && mounted) setState(() {});
      });
      return _buildVideoFallback();
    }
    return Image.file(
      File(item.filePath),
      cacheWidth: 100,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: AppColors.surfaceBorder,
        child: const Icon(Icons.image, size: 20, color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildVideoFallback() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Icon(Icons.videocam_rounded, size: 20, color: AppColors.accentOrange),
      ),
    );
  }

  Widget _buildContent(double width, {bool isGhost = false}) {
    final item = widget.item;
    final isHoveredOrSelected = _isHovered || widget.isSelected;
    final isSwap = _dropSide == 2;

    return Container(
      width: width, height: 64, margin: const EdgeInsets.only(right: 1),
      decoration: BoxDecoration(
        color: item.isColorBackground ? (item.backgroundColor ?? AppColors.surfaceLight) : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: isSwap ? AppColors.exportGreen : (widget.isSelected ? AppColors.accentOrange : (item.isColorBackground ? Colors.purpleAccent : AppColors.surfaceBorder)),
          width: (widget.isSelected || isSwap) ? 2.0 : 1.0,
        ),
        boxShadow: [if (widget.isSelected || isSwap) BoxShadow(color: (isSwap ? AppColors.exportGreen : AppColors.accentOrange).withValues(alpha: 0.5), blurRadius: 6)],
      ),
      clipBehavior: Clip.none,
      child: Opacity(
        opacity: isGhost ? 0.35 : 1.0,
        child: Stack(
          clipBehavior: Clip.none, fit: StackFit.expand,
          children: [
            if (!item.isColorBackground && width >= 16)
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Opacity(
                  opacity: 0.55,
                  child: _buildMediaThumbnail(item),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Container(decoration: BoxDecoration(color: item.backgroundColor?.withValues(alpha: 0.85) ?? Colors.black), child: const Center(child: Icon(Icons.palette_outlined, size: 18, color: Colors.white54))),
              ),
            if (width >= 34)
              Padding(
                padding: const EdgeInsets.all(3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: item.isVideo
                                ? AppColors.accentOrange
                                : (item.isColorBackground ? Colors.purpleAccent : AppColors.clipBlue),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text('#${item.orderIndex + 1}', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        if (isHoveredOrSelected && width >= 75) ...[
                          const SizedBox(width: 2),
                          InkWell(onTap: () => _swapWith(item.orderIndex - 1), child: const Icon(Icons.chevron_left, size: 14, color: Colors.white70)),
                          InkWell(onTap: () => _swapWith(item.orderIndex + 1), child: const Icon(Icons.chevron_right, size: 14, color: Colors.white70)),
                        ],
                        if (width >= 85) ...[
                          const SizedBox(width: 4),
                          Expanded(child: Text(item.isColorBackground ? 'Color BG' : item.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white))),
                        ],
                      ],
                    ),
                    if (width >= 55)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (item.isMarked)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.bookmark, size: 12, color: Colors.amber),
                            ),
                          Container(
                            constraints: const BoxConstraints(maxWidth: 36),
                            padding: const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(2)),
                            child: FittedBox(fit: BoxFit.scaleDown, child: Text('${(item.durationMs / 1000).toStringAsFixed(1)}s', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            if (!isGhost) ...[
              Positioned(right: 0, top: 0, bottom: 0, child: ClipTrimHandle(item: item, zoomScale: widget.zoomScale, isClipHoveredOrSelected: isHoveredOrSelected)),
              if (isHoveredOrSelected) Positioned(right: -9, top: 23, child: ClipInsertButton(afterClip: item)),
            ],
            if (_dropSide == 1)
              Positioned(left: 0, top: 0, bottom: 0, width: 4, child: Container(decoration: BoxDecoration(color: AppColors.clipBlueLight, borderRadius: BorderRadius.circular(2), boxShadow: const [BoxShadow(color: Colors.cyanAccent, blurRadius: 6)]))),
            if (_dropSide == 3)
              Positioned(right: 0, top: 0, bottom: 0, width: 4, child: Container(decoration: BoxDecoration(color: AppColors.clipBlueLight, borderRadius: BorderRadius.circular(2), boxShadow: const [BoxShadow(color: Colors.cyanAccent, blurRadius: 6)]))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pxPerSec = TimelineZoomController.pxPerSec(widget.zoomScale);
    final width = ((widget.item.durationMs / 1000) * pxPerSec).clamp(2.0, 50000.0);
    final item = widget.item;

    return DragTarget<ImageItem>(
      onWillAcceptWithDetails: (details) => details.data.id != item.id,
      onMove: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.hasSize && box.size.width > 0) {
          final local = box.globalToLocal(details.offset);
          final relX = local.dx / box.size.width;
          final side = relX < 0.28 ? 1 : (relX > 0.72 ? 3 : 2);
          if (side != _dropSide) setState(() => _dropSide = side);
        }
      },
      onLeave: (_) { if (_dropSide != 0) setState(() => _dropSide = 0); },
      onAcceptWithDetails: (details) {
        final side = _dropSide;
        setState(() => _dropSide = 0);
        if (side == 1) {
          ref.read(projectProvider.notifier).reorderAndOccupy(details.data.id, item.id, insertBefore: true);
        } else if (side == 3) {
          ref.read(projectProvider.notifier).reorderAndOccupy(details.data.id, item.id, insertBefore: false);
        } else {
          ref.read(projectProvider.notifier).swapImageClips(details.data.id, item.id);
        }
      },
      builder: (context, candidateData, _) {
        return MouseRegion(
          cursor: SystemMouseCursors.grab,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: Draggable<ImageItem>(
            data: item,
            feedback: Material(
              elevation: 8, borderRadius: BorderRadius.circular(4), color: Colors.transparent,
              child: SizedBox(
                width: 75, height: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: item.isColorBackground
                      ? Container(color: item.backgroundColor ?? Colors.purpleAccent, child: const Icon(Icons.palette_outlined, size: 24, color: Colors.white70))
                      : _buildMediaThumbnail(item),
                ),
              ),
            ),
            childWhenDragging: _buildContent(width, isGhost: true),
            child: GestureDetector(
              onTap: widget.onTap,
              onSecondaryTapUp: (details) => AssetContextMenus.showMediaClipMenu(
                context: context,
                ref: ref,
                globalPosition: details.globalPosition,
                item: item,
              ),
              child: _buildContent(width),
            ),
          ),
        );
      },
    );
  }
}
