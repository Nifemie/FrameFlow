import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/image_item.dart';
import '../../../models/timeline_track_item.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../services/playback_controller.dart';
import '../../../services/timeline_arrangement_service.dart';
import 'asset_context_menus.dart';
import 'timeline_clip.dart';
import 'timeline_gap_item.dart';

class MediaTrackStrip extends ConsumerWidget {
  final TimelineTrackItem track;
  final List<ImageItem> images;
  final double contentWidth;
  final double pxPerSec;
  final double zoom;
  final String emptyLabel;
  final VoidCallback onAdd;
  final VoidCallback? onAddFolder;

  const MediaTrackStrip({
    super.key,
    required this.track,
    required this.images,
    required this.contentWidth,
    required this.pxPerSec,
    required this.zoom,
    required this.emptyLabel,
    required this.onAdd,
    this.onAddFolder,
  });

  List<Widget> _buildGaps(WidgetRef ref) {
    final explicitGaps = ref.watch(projectProvider.select((p) => p.explicitGaps));
    return explicitGaps
        .where((g) => g.trackId == track.id && g.durationMs > 100)
        .map((g) => TimelineGapItem(
              key: ValueKey('gap_${g.id}'),
              gapId: g.id,
              startMs: g.startMs,
              endMs: g.endMs,
              pxPerSec: pxPerSec,
              trackId: g.trackId,
              onTap: () => ref.read(playbackControllerProvider).seek(g.startMs),
            ))
        .toList();
  }

  int _computeDropStartMs(BuildContext context, WidgetRef ref, Offset globalOffset) {
    final box = context.findRenderObject() as RenderBox?;
    int rawMs = 0;
    if (box != null && box.hasSize) {
      final centerGlobal = Offset(globalOffset.dx + 37.5, globalOffset.dy);
      final local = box.globalToLocal(centerGlobal);
      rawMs = ((local.dx.clamp(0.0, box.size.width) / pxPerSec) * 1000).round();
    }
    final snapOn = ref.read(snappingEnabledProvider);
    if (!snapOn) return rawMs;
    final project = ref.read(projectProvider);
    final targets = <int>[
      0,
      ref.read(playheadPositionProvider),
      ...project.markers.map((m) => m.timestampMs),
      ...project.images.expand((i) => [i.startMs, i.endMs]),
    ];
    final (snapped, _) = TimelineArrangementService.snapToTargets(
      targetMs: rawMs,
      targets: targets,
      pxPerSec: pxPerSec,
      enabled: true,
    );
    return snapped;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedImageIdProvider);
    final selectedIds = ref.watch(selectedClipIdsProvider);

    if (images.isEmpty) {
      return GestureDetector(
        onSecondaryTapUp: (details) => AssetContextMenus.showTimelineMenu(
          context: context,
          ref: ref,
          globalPosition: details.globalPosition,
          track: track,
          onAddMedia: onAdd,
          onAddFolder: onAddFolder,
          onAddBg: () => ref.read(projectProvider.notifier).addColorBackground(trackId: track.id),
        ),
        child: DragTarget<ImageItem>(
          onWillAcceptWithDetails: (_) => true,
          onAcceptWithDetails: (details) {
            final dropStartMs = _computeDropStartMs(context, ref, details.offset);
            ref.read(projectProvider.notifier).placeClipOnTrack(
              clip: details.data,
              targetTrackId: track.id,
              startMs: dropStartMs,
            );
          },
        builder: (context, candidateData, _) {
          final isDropHover = candidateData.isNotEmpty;
          return Container(
            height: 64, width: contentWidth,
            decoration: BoxDecoration(
              color: isDropHover ? AppColors.accentOrange.withValues(alpha: 0.15) : AppColors.surfaceLight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: isDropHover ? AppColors.accentOrange : AppColors.surfaceBorder, width: isDropHover ? 1.5 : 0.8),
            ),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accentOrange,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_photo_alternate, size: 14, color: AppColors.accentOrange),
                    label: Text(
                      emptyLabel,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.accentOrange, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (onAddFolder != null) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentOrange,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: onAddFolder,
                      icon: const Icon(Icons.folder_open, size: 14, color: AppColors.accentOrange),
                      label: const Text(
                        'Import Folder',
                        style: TextStyle(fontSize: 10.5, color: AppColors.accentOrange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
      );
    }

    return GestureDetector(
      onSecondaryTapUp: (details) => AssetContextMenus.showTimelineMenu(
        context: context,
        ref: ref,
        globalPosition: details.globalPosition,
        track: track,
        onAddMedia: onAdd,
        onAddFolder: onAddFolder,
        onAddBg: () => ref.read(projectProvider.notifier).addColorBackground(trackId: track.id),
      ),
      child: DragTarget<ImageItem>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) {
          final dropped = details.data;
          final dropStartMs = _computeDropStartMs(context, ref, details.offset);
          ref.read(projectProvider.notifier).placeClipOnTrack(
            clip: dropped,
            targetTrackId: track.id,
            startMs: dropStartMs,
          );
        },
      builder: (context, candidateData, _) {
        final isDropHover = candidateData.isNotEmpty;
        return Container(
          height: 64, width: contentWidth,
          decoration: isDropHover ? BoxDecoration(
            border: Border.all(color: AppColors.accentOrange, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ) : null,
          child: Stack(
            children: [
              ..._buildGaps(ref),
              ...images.map((img) {
                final isSelected = selectedIds.contains(img.id) || img.id == selectedId;
                return Positioned(
                  left: (img.startMs / 1000) * pxPerSec, top: 0, bottom: 0,
                  width: max(2.0, (img.durationMs / 1000) * pxPerSec),
                  child: TimelineClip(
                    key: ValueKey(img.id), item: img, isSelected: isSelected, zoomScale: zoom,
                    onTap: () {
                      final isCtrl = HardwareKeyboard.instance.isControlPressed;
                      final isShift = HardwareKeyboard.instance.isShiftPressed;

                      if (isCtrl) {
                        final current = Set<String>.from(ref.read(selectedClipIdsProvider));
                        if (current.contains(img.id)) {
                          current.remove(img.id);
                        } else {
                          current.add(img.id);
                        }
                        ref.read(selectedClipIdsProvider.notifier).state = current;
                        ref.read(selectedImageIdProvider.notifier).state = current.isNotEmpty ? current.last : null;
                      } else if (isShift && selectedId != null) {
                        final idx1 = images.indexWhere((i) => i.id == selectedId);
                        final idx2 = images.indexWhere((i) => i.id == img.id);
                        if (idx1 >= 0 && idx2 >= 0) {
                          final start = min(idx1, idx2);
                          final end = max(idx1, idx2);
                          final range = images.sublist(start, end + 1).map((i) => i.id).toSet();
                          ref.read(selectedClipIdsProvider.notifier).state = range;
                        }
                      } else {
                        SelectionHelper.selectImage(ref, img.id);
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    ),
    );
  }
}
