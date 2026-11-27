import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';
import '../../../models/timeline_track_item.dart';
import '../../../providers/export_range_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/playback_controller.dart';
import '../../../services/timeline_arrangement_service.dart';
import '../media/widgets/folder_import_dialog.dart';
import 'services/timeline_zoom_controller.dart';
import 'widgets/audio_waveform_strip.dart';
import 'widgets/media_track_strip.dart';
import 'widgets/playhead_needle.dart';
import 'widgets/text_timeline_strip.dart';
import 'widgets/timeline_ruler.dart';
import 'widgets/track_header_column.dart';

class TimelineContainer extends ConsumerStatefulWidget {
  const TimelineContainer({super.key});

  @override
  ConsumerState<TimelineContainer> createState() => _TimelineContainerState();
}

class _TimelineContainerState extends ConsumerState<TimelineContainer> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _tracksVerticalController = ScrollController();
  final ScrollController _headersVerticalController = ScrollController();
  bool _isSyncingScroll = false;

  double? _dragStartX, _dragStartScroll;
  double _dragCurrentPlayheadX = 0;

  @override
  void initState() {
    super.initState();
    _tracksVerticalController.addListener(() {
      if (_isSyncingScroll) return;
      _isSyncingScroll = true;
      if (_headersVerticalController.hasClients) {
        _headersVerticalController.jumpTo(_tracksVerticalController.offset.clamp(0.0, _headersVerticalController.position.maxScrollExtent));
      }
      _isSyncingScroll = false;
    });
    _headersVerticalController.addListener(() {
      if (_isSyncingScroll) return;
      _isSyncingScroll = true;
      if (_tracksVerticalController.hasClients) {
        _tracksVerticalController.jumpTo(_headersVerticalController.offset.clamp(0.0, _tracksVerticalController.position.maxScrollExtent));
      }
      _isSyncingScroll = false;
    });
  }

  (int, int?) _snapPlayheadMs(int rawMs, double pxPerSec) {
    final snapOn = ref.read(snappingEnabledProvider);
    if (!snapOn) return (rawMs, null);
    final project = ref.read(projectProvider);
    final targets = <int>[
      0,
      if (project.totalDurationMs > 0) project.totalDurationMs,
      ...project.markers.map((m) => m.timestampMs),
      ...project.images.expand((i) => [i.startMs, i.endMs]),
      ...project.textOverlays.expand((t) => [t.startMs, t.endMs]),
      ...project.effectiveAudioClips.expand((a) => [a.startTimelineMs, a.endTimelineMs]),
    ];
    return TimelineArrangementService.snapToTargets(
      targetMs: rawMs,
      targets: targets,
      pxPerSec: pxPerSec,
      enabled: true,
    );
  }

  void _handleSeek(int ms) {
    final zoom = ref.read(timelineZoomProvider);
    final pxPerSec = TimelineZoomController.pxPerSec(zoom);
    final (snapped, _) = _snapPlayheadMs(ms, pxPerSec);
    ref.read(playbackControllerProvider).seek(snapped);
  }

  Future<void> _showRulerContextMenu(
    BuildContext context,
    TapUpDetails details,
    int clickMs,
    int totalDurationMs,
  ) async {
    final rangeState = ref.read(exportRangeProvider);
    final rangeNotifier = ref.read(exportRangeProvider.notifier);
    final timeLabel = TimeParser.formatStandard(clickMs);
    final hitSavedIdx = rangeState.savedRanges.indexWhere((r) => clickMs >= r.startMs && clickMs <= r.endMs);
    final hitActive = rangeState.hasRange && clickMs >= rangeState.inMs! && clickMs <= rangeState.outMs!;

    final selected = await showMenu<String>(
      context: context,
      color: AppColors.surface,
      constraints: const BoxConstraints(minWidth: 230, maxWidth: 380),
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx,
        details.globalPosition.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'add_new_range_here',
          child: Row(children: [
            const Icon(Icons.add_box_outlined, size: 15, color: Colors.tealAccent),
            const SizedBox(width: 8),
            Flexible(child: Text('Add New Range Here ($timeLabel)', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white))),
          ]),
        ),
        PopupMenuItem(
          value: 'set_in',
          child: Row(children: [
            const Icon(Icons.first_page, size: 15, color: AppColors.exportGreen),
            const SizedBox(width: 8),
            Flexible(child: Text('Set Export In Point ($timeLabel)', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white))),
          ]),
        ),
        PopupMenuItem(
          value: 'set_out',
          child: Row(children: [
            const Icon(Icons.last_page, size: 15, color: AppColors.exportGreen),
            const SizedBox(width: 8),
            Flexible(child: Text('Set Export Out Point ($timeLabel)', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white))),
          ]),
        ),
        if (rangeState.hasRange)
          const PopupMenuItem(
            value: 'queue_range',
            child: Row(children: [
              Icon(Icons.playlist_add, size: 15, color: AppColors.exportGreen),
              SizedBox(width: 8),
              Text('Save Range & Mark Next', style: TextStyle(fontSize: 12, color: Colors.white)),
            ]),
          ),
        if (hitSavedIdx >= 0)
          PopupMenuItem(
            value: 'delete_hit_saved',
            child: Row(children: [
              const Icon(Icons.delete_outline, size: 15, color: AppColors.errorRed),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Delete Range #${hitSavedIdx + 1}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.errorRed),
                ),
              ),
            ]),
          ),
        if (hitActive || (hitSavedIdx < 0 && (rangeState.inMs != null || rangeState.outMs != null)))
          const PopupMenuItem(
            value: 'clear_range',
            child: Row(children: [
              Icon(Icons.clear_all, size: 15, color: Colors.white70),
              SizedBox(width: 8),
              Text('Delete Active Range', style: TextStyle(fontSize: 12, color: Colors.white)),
            ]),
          ),
        if (rangeState.savedRanges.isNotEmpty)
          const PopupMenuItem(
            value: 'clear_all_saved',
            child: Row(children: [
              Icon(Icons.layers_clear, size: 15, color: AppColors.errorRed),
              SizedBox(width: 8),
              Text('Delete All Ranges', style: TextStyle(fontSize: 12, color: AppColors.errorRed)),
            ]),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'add_marker',
          child: Row(children: [
            const Icon(Icons.bookmark_add_outlined, size: 15, color: Colors.amber),
            const SizedBox(width: 8),
            Flexible(child: Text('Add Marker Here ($timeLabel)', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white))),
          ]),
        ),
        PopupMenuItem(
          value: 'seek_here',
          child: Row(children: [
            const Icon(Icons.my_location, size: 15, color: AppColors.accentOrange),
            const SizedBox(width: 8),
            Flexible(child: Text('Move Playhead Here ($timeLabel)', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white))),
          ]),
        ),
      ],
    );

    if (!mounted || selected == null) return;
    switch (selected) {
      case 'add_new_range_here':
        final maxMs = totalDurationMs > 500 ? totalDurationMs : 30000;
        final start = clickMs.clamp(0, maxMs - 500);
        final end = (start + 5000).clamp(start + 500, maxMs);
        rangeNotifier.addRange(ExportRange(startMs: start, endMs: end));
        break;
      case 'set_in':
        rangeNotifier.setInPoint(clickMs, totalDurationMs: totalDurationMs);
        break;
      case 'set_out':
        rangeNotifier.setOutPoint(clickMs, totalDurationMs: totalDurationMs);
        break;
      case 'queue_range':
        rangeNotifier.commitActiveRange();
        break;
      case 'delete_hit_saved':
        if (hitSavedIdx >= 0) rangeNotifier.removeSavedRange(hitSavedIdx);
        break;
      case 'clear_range':
        rangeNotifier.clearRange();
        break;
      case 'clear_all_saved':
        rangeNotifier.clearRange();
        rangeNotifier.clearSavedRanges();
        break;
      case 'add_marker':
        final count = ref.read(projectProvider).markers.length + 1;
        ref.read(projectProvider.notifier).addMarker(clickMs, label: 'Marker $count');
        break;
      case 'seek_here':
        _handleSeek(clickMs);
        break;
    }
  }

  void _handleNeedleDragStart(DragStartDetails d, int ms, double pxPerSec) {
    ref.read(playbackControllerProvider).pause();
    _dragCurrentPlayheadX = (ms / 1000.0) * pxPerSec;
  }

  void _handleNeedleDragUpdate(DragUpdateDetails d, double pxPerSec, int totalMs) {
    _dragCurrentPlayheadX += d.delta.dx;
    final maxMs = max(totalMs, ref.read(projectProvider).totalDurationMs);
    final rawMs = ((_dragCurrentPlayheadX / pxPerSec) * 1000).round().clamp(0, maxMs);
    final (snappedMs, snapLine) = _snapPlayheadMs(rawMs, pxPerSec);
    ref.read(activeSnapLineMsProvider.notifier).state = snapLine;
    ref.read(playbackControllerProvider).scrub(snappedMs.clamp(0, maxMs));
    if (_scrollController.hasClients) {
      final off = _scrollController.offset, viewW = _scrollController.position.viewportDimension;
      if (_dragCurrentPlayheadX > off + viewW - 40) _scrollController.jumpTo((off + 15).clamp(0.0, _scrollController.position.maxScrollExtent));
      if (_dragCurrentPlayheadX < off + 40 && off > 0) _scrollController.jumpTo((off - 15).clamp(0.0, _scrollController.position.maxScrollExtent));
    }
  }

  void _handleNeedleDragEnd() {
    ref.read(activeSnapLineMsProvider.notifier).state = null;
    final ms = ref.read(playheadPositionProvider);
    ref.read(playbackControllerProvider).seek(ms, syncAudioImmediately: true);
  }

  void _zoomFit() {
    final totalMs = ref.read(projectProvider).totalDurationMs;
    final viewportW = _scrollController.hasClients ? _scrollController.position.viewportDimension : 800.0;
    final fitZoom = TimelineZoomController.calculateFitZoom(totalDurationMs: totalMs, viewportWidth: viewportW);
    ref.read(timelineZoomProvider.notifier).state = fitZoom;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tracksVerticalController.dispose();
    _headersVerticalController.dispose();
    super.dispose();
  }

  void _handleZoomAnchor(double delta, double localX, double currentZoom) {
    final newZoom = (currentZoom + delta).clamp(TimelineZoomController.minZoom, TimelineZoomController.maxZoom);
    if ((newZoom - currentZoom).abs() < 0.001) return;
    if (_scrollController.hasClients) {
      final newScroll = TimelineZoomController.calculateAnchoredScroll(currentScroll: _scrollController.offset, anchorScreenX: localX, oldZoom: currentZoom, newZoom: newZoom);
      ref.read(timelineZoomProvider.notifier).state = newZoom;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) _scrollController.jumpTo(newScroll.clamp(0.0, _scrollController.position.maxScrollExtent));
      });
    } else {
      ref.read(timelineZoomProvider.notifier).state = newZoom;
    }
  }

  void _handlePointerSignal(PointerSignalEvent event, double zoom) {
    if (event is! PointerScrollEvent) return;
    if (HardwareKeyboard.instance.isControlPressed) {
      _handleZoomAnchor(-event.scrollDelta.dy * 0.0015, event.localPosition.dx, zoom);
      return;
    }
    // Trackpad 2-finger horizontal swipe (event.scrollDelta.dx != 0) is natively handled
    // by SingleChildScrollView with momentum.
    // For standard mouse wheel (dx == 0, dy != 0), translate wheel ticks directly to horizontal timeline scrolling.
    if (_scrollController.hasClients && event.scrollDelta.dx == 0 && event.scrollDelta.dy != 0) {
      final target = (_scrollController.offset + event.scrollDelta.dy).clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.jumpTo(target);
    }
  }

  Future<void> _pickImagesForTrack(String trackId) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: [...AppConstants.supportedImageExtensions, ...AppConstants.supportedVideoExtensions], allowMultiple: true);
    if (result != null) {
      final playheadMs = ref.read(playheadPositionProvider);
      ref.read(projectProvider.notifier).addImages(result.paths.whereType<String>().toList(), trackId: trackId, insertAtMs: playheadMs);
    }
  }

  Future<void> _pickFolderForTrack(String trackId) async {
    final folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath == null || !mounted) return;
    showDialog(
      context: context,
      builder: (_) => FolderImportDialog(
        directoryPath: folderPath,
        onImportConfirmed: (paths, stamps) {
          if (paths.isEmpty) return;
          final playheadMs = ref.read(playheadPositionProvider);
          ref.read(projectProvider.notifier).addImages(paths, trackId: trackId, insertAtMs: playheadMs);
          if (stamps.isNotEmpty) ref.read(projectProvider.notifier).applyBulkTimestamps(stamps, trackId: trackId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider);
    final totalDurationMs = project.totalDurationMs;
    final tracks = project.effectiveTracks;
    final zoom = ref.watch(timelineZoomProvider);

    final pxPerSec = TimelineZoomController.pxPerSec(zoom);
    final contentWidth = max(1200.0, (((totalDurationMs > 0 ? totalDurationMs : 10000) / 1000) * pxPerSec) + 800);

    ref.listen<int>(playheadPositionProvider, (_, current) {
      if (!ref.read(isPlayingProvider) || !_scrollController.hasClients) return;
      final curX = (current / 1000) * pxPerSec, off = _scrollController.offset, viewW = _scrollController.position.viewportDimension;
      if (curX > off + viewW - 60) {
        _scrollController.animateTo(
          (curX - 60).clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });

    final theme = ref.watch(themeProvider);
    final timelineHeaderColor = Color.lerp(theme.timelineColor, Colors.white, 0.04) ?? theme.timelineColor;

    return Container(
      color: theme.timelineColor,
      child: Column(
        children: [
          // Timeline Quick Control Bar: Zoom Slider & Fit to Project
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: timelineHeaderColor,
              border: const Border(bottom: BorderSide(color: AppColors.surfaceBorder, width: 0.8)),
            ),
            child: Row(
              children: [
                Icon(Icons.view_timeline_rounded, size: 14, color: theme.iconColor('timelineHeader', theme.buttonColor)),
                const SizedBox(width: 6),
                Text(
                  'TIMELINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 12),
                // CapCut-style Snapping Toggle
                Consumer(
                  builder: (context, ref, _) {
                    final snapOn = ref.watch(snappingEnabledProvider);
                    return InkWell(
                      onTap: () => ref.read(snappingEnabledProvider.notifier).state = !snapOn,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: snapOn ? AppColors.accentOrange.withValues(alpha: 0.2) : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: snapOn ? AppColors.accentOrange : AppColors.surfaceBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.vertical_align_center, size: 11, color: snapOn ? theme.iconColor('snapToggle', theme.buttonColor) : AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              snapOn ? 'Snap ON' : 'Snap OFF',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: snapOn ? AppColors.accentOrange : AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                // Add Timeline Marker at Playhead
                InkWell(
                  onTap: () {
                    final ms = ref.read(playheadPositionProvider);
                    ref.read(projectProvider.notifier).addMarker(ms, label: 'Marker ${project.markers.length + 1}');
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_add_outlined, size: 11, color: theme.iconColor('markK', Colors.amber)),
                        const SizedBox(width: 4),
                        const Text('Mark (K)', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Auto-Rearrange from Left (Pack)
                InkWell(
                  onTap: () => ref.read(projectProvider.notifier).autoArrangeFromLeft(),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.format_align_left, size: 11, color: theme.iconColor('packLeft', Colors.cyanAccent)),
                        const SizedBox(width: 4),
                        const Text('Pack Left', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Export Range In / Out / Clear Controls
                Consumer(
                  builder: (context, ref, _) {
                    final rangeState = ref.watch(exportRangeProvider);
                    final rangeNotifier = ref.read(exportRangeProvider.notifier);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => rangeNotifier.setInPoint(
                            ref.read(playheadPositionProvider),
                            totalDurationMs: totalDurationMs,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: rangeState.inMs != null ? AppColors.exportGreen.withValues(alpha: 0.2) : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: rangeState.inMs != null ? AppColors.exportGreen : AppColors.surfaceBorder),
                            ),
                            child: Text(
                              'In (I)',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: rangeState.inMs != null ? AppColors.exportGreen : Colors.white70),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => rangeNotifier.setOutPoint(
                            ref.read(playheadPositionProvider),
                            totalDurationMs: totalDurationMs,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: rangeState.outMs != null ? AppColors.exportGreen.withValues(alpha: 0.2) : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: rangeState.outMs != null ? AppColors.exportGreen : AppColors.surfaceBorder),
                            ),
                            child: Text(
                              'Out (O)',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: rangeState.outMs != null ? AppColors.exportGreen : Colors.white70),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            if (rangeState.hasRange) {
                              rangeNotifier.commitActiveRange();
                            } else {
                              final playhead = ref.read(playheadPositionProvider);
                              final maxMs = totalDurationMs > 500 ? totalDurationMs : 30000;
                              final start = playhead.clamp(0, maxMs - 500);
                              final end = (start + 5000).clamp(start + 500, maxMs);
                              rangeNotifier.addRange(ExportRange(startMs: start, endMs: end));
                            }
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.tealAccent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.tealAccent),
                            ),
                            child: const Text(
                              '+ Range',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                            ),
                          ),
                        ),
                        if (rangeState.savedRanges.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.tealAccent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.6)),
                            ),
                            child: Text(
                              '${rangeState.savedRanges.length} Range${rangeState.savedRanges.length == 1 ? '' : 's'}',
                              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                            ),
                          ),
                        ],
                        if (rangeState.inMs != null || rangeState.outMs != null) ...[
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: rangeNotifier.clearRange,
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.surfaceBorder),
                              ),
                              child: const Icon(Icons.close, size: 11, color: Colors.white70),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.remove, size: 14, color: theme.iconColor('zoomOutIn', AppColors.textSecondary)),
                  tooltip: 'Zoom Out (-)',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 14,
                  onPressed: () {
                    final z = (zoom - 0.25).clamp(TimelineZoomController.minZoom, TimelineZoomController.maxZoom);
                    ref.read(timelineZoomProvider.notifier).state = z;
                  },
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 100,
                  height: 20,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                      activeTrackColor: AppColors.accentOrange,
                      thumbColor: AppColors.accentOrange,
                      inactiveTrackColor: AppColors.surfaceBorder,
                    ),
                    child: Slider(
                      value: zoom.clamp(TimelineZoomController.minZoom, TimelineZoomController.maxZoom),
                      min: TimelineZoomController.minZoom,
                      max: TimelineZoomController.maxZoom,
                      onChanged: (val) {
                        ref.read(timelineZoomProvider.notifier).state = val;
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.add, size: 14, color: theme.iconColor('zoomOutIn', AppColors.textSecondary)),
                  tooltip: 'Zoom In (+)',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 14,
                  onPressed: () {
                    final z = (zoom + 0.25).clamp(TimelineZoomController.minZoom, TimelineZoomController.maxZoom);
                    ref.read(timelineZoomProvider.notifier).state = z;
                  },
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: _zoomFit,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fit_screen_rounded, size: 11, color: theme.iconColor('zoomFit', theme.buttonColor)),
                        const SizedBox(width: 4),
                        const Text('Fit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Tracks & Ruler Area
          Expanded(
            child: Row(
              children: [
                TrackHeaderColumn(scrollController: _headersVerticalController),
                Expanded(
                  child: Listener(
                    onPointerSignal: (e) => _handlePointerSignal(e, zoom),
                    onPointerDown: (e) {
                      if (e.buttons == 4 || (e.buttons == 1 && HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.space))) {
                        _dragStartX = e.position.dx;
                        _dragStartScroll = _scrollController.hasClients ? _scrollController.offset : 0;
                      }
                    },
                    onPointerMove: (e) {
                      if (_dragStartX != null && _dragStartScroll != null && _scrollController.hasClients) {
                        _scrollController.jumpTo((_dragStartScroll! - (e.position.dx - _dragStartX!)).clamp(0.0, _scrollController.position.maxScrollExtent));
                      }
                    },
                    onPointerUp: (_) => _dragStartX = _dragStartScroll = null,
                    child: RawScrollbar(
                      controller: _scrollController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      thumbColor: AppColors.surfaceBorder.withValues(alpha: 0.8),
                      thickness: 8,
                      radius: const Radius.circular(4),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          ref.read(selectedClipIdsProvider.notifier).state = {};
                          ref.read(selectedImageIdProvider.notifier).state = null;
                          ref.read(selectedAudioClipIdProvider.notifier).state = null;
                        },
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context).copyWith(
                                dragDevices: {
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.trackpad,
                                  PointerDeviceKind.stylus,
                                  PointerDeviceKind.invertedStylus,
                                },
                              ),
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                scrollDirection: Axis.horizontal,
                                physics: const ClampingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: SizedBox(
                                width: contentWidth,
                                height: constraints.maxHeight,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        TimelineRuler(
                                          totalDurationMs: totalDurationMs,
                                          pixelsPerSecond: pxPerSec,
                                          onSeek: _handleSeek,
                                          onScrub: (ms) => ref.read(playbackControllerProvider).scrub(ms),
                                          onScrubEnd: () => ref.read(playbackControllerProvider).seek(ref.read(playheadPositionProvider), syncAudioImmediately: true),
                                          onSecondaryTapUp: (details, clickMs) => _showRulerContextMenu(context, details, clickMs, totalDurationMs),
                                        ),
                                        const SizedBox(height: 6),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            controller: _tracksVerticalController,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                for (final tr in tracks) ...[
                                                  if (tr.isVideoOrBg) ...[
                                                    Opacity(
                                                      opacity: tr.isVisible ? 1.0 : 0.32,
                                                      child: MediaTrackStrip(
                                                        track: tr,
                                                        images: project.imagesForTrack(tr.id),
                                                        contentWidth: contentWidth,
                                                        pxPerSec: pxPerSec,
                                                        zoom: zoom,
                                                        emptyLabel: '+ Add Videos / Images / BG to ${tr.name}',
                                                        onAdd: () => _pickImagesForTrack(tr.id),
                                                        onAddFolder: () => _pickFolderForTrack(tr.id),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                  ] else if (tr.type == TrackType.text) ...[
                                                    Opacity(
                                                      opacity: tr.isVisible ? 1.0 : 0.32,
                                                      child: TextTimelineStrip(pxPerSec: pxPerSec, contentWidth: contentWidth),
                                                    ),
                                                    const SizedBox(height: 4),
                                                  ] else if (tr.type == TrackType.audio) ...[
                                                    Opacity(
                                                      opacity: tr.isVisible ? 1.0 : 0.32,
                                                      child: AudioWaveformStrip(pxPerSec: pxPerSec, contentWidth: contentWidth),
                                                    ),
                                                    const SizedBox(height: 4),
                                                  ],
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Timeline Markers (clickable pins + vertical guide lines)
                                    for (final marker in project.markers)
                                      Positioned(
                                        left: (marker.timestampMs / 1000) * pxPerSec - 6,
                                        top: 0,
                                        bottom: 0,
                                        width: 12,
                                        child: GestureDetector(
                                          onTap: () => _handleSeek(marker.timestampMs),
                                          onSecondaryTapUp: (details) async {
                                            final action = await showMenu<String>(
                                              context: context,
                                              color: AppColors.surface,
                                              position: RelativeRect.fromLTRB(details.globalPosition.dx, details.globalPosition.dy, details.globalPosition.dx, details.globalPosition.dy),
                                              items: const [
                                                PopupMenuItem(value: 'seek', child: Text('Jump to Marker', style: TextStyle(fontSize: 11, color: Colors.white))),
                                                PopupMenuItem(value: 'delete', child: Text('Delete Marker', style: TextStyle(fontSize: 11, color: AppColors.errorRed))),
                                              ],
                                            );
                                            if (action == 'seek') _handleSeek(marker.timestampMs);
                                            if (action == 'delete') ref.read(projectProvider.notifier).removeMarker(marker.id);
                                          },
                                          child: Tooltip(
                                            message: marker.label,
                                            child: Column(
                                              children: [
                                                Icon(Icons.bookmark, size: 13, color: marker.color),
                                                Expanded(child: Container(width: 1, color: marker.color.withValues(alpha: 0.5))),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                    // Export In / Out Range Highlights & Draggable Handles (Saved + Active)
                                    Consumer(
                                      builder: (context, ref, _) {
                                        final rangeState = ref.watch(exportRangeProvider);
                                        final rangeNotifier = ref.read(exportRangeProvider.notifier);
                                        final inMs = rangeState.inMs;
                                        final outMs = rangeState.outMs;
                                        if (inMs == null && outMs == null && rangeState.savedRanges.isEmpty) {
                                          return const SizedBox.shrink();
                                        }
                                        final effectiveIn = inMs ?? 0;
                                        final effectiveOut = outMs ?? totalDurationMs;
                                        final hasBand = (inMs != null || outMs != null) && effectiveOut > effectiveIn;
                                        final leftX = (effectiveIn / 1000) * pxPerSec;
                                        final rightX = (effectiveOut / 1000) * pxPerSec;

                                        return Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            // Saved multiple ranges
                                            for (int i = 0; i < rangeState.savedRanges.length; i++) ...[
                                              Builder(
                                                builder: (_) {
                                                  final r = rangeState.savedRanges[i];
                                                  final rLeft = (r.startMs / 1000) * pxPerSec;
                                                  final rRight = (r.endMs / 1000) * pxPerSec;
                                                  return Stack(
                                                    clipBehavior: Clip.none,
                                                    children: [
                                                      Positioned(
                                                        left: rLeft,
                                                        top: 0,
                                                        bottom: 0,
                                                        width: (rRight - rLeft).clamp(2.0, double.infinity),
                                                        child: IgnorePointer(
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              color: Colors.tealAccent.withValues(alpha: 0.12),
                                                              border: const Border(
                                                                left: BorderSide(color: Colors.tealAccent, width: 1.5),
                                                                right: BorderSide(color: Colors.tealAccent, width: 1.5),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      // Badge #i + remove button
                                                      Positioned(
                                                        left: rLeft + 8,
                                                        top: 2,
                                                        child: Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                          decoration: BoxDecoration(
                                                            color: Colors.teal.shade700,
                                                            borderRadius: BorderRadius.circular(3),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text('#${i + 1}', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                                              const SizedBox(width: 3),
                                                              GestureDetector(
                                                                onTap: () => rangeNotifier.removeSavedRange(i),
                                                                child: const Icon(Icons.close, size: 9, color: Colors.white),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      // Draggable Left Handle
                                                      Positioned(
                                                        left: rLeft - 6,
                                                        top: 0,
                                                        width: 12,
                                                        height: 22,
                                                        child: MouseRegion(
                                                          cursor: SystemMouseCursors.resizeLeftRight,
                                                          child: GestureDetector(
                                                            behavior: HitTestBehavior.opaque,
                                                            onHorizontalDragUpdate: (d) {
                                                              final deltaMs = ((d.delta.dx / pxPerSec) * 1000).round();
                                                              final cur = ref.read(exportRangeProvider).savedRanges[i];
                                                              final nextStart = (cur.startMs + deltaMs).clamp(0, cur.endMs - 200);
                                                              rangeNotifier.updateSavedRange(i, cur.copyWith(startMs: nextStart));
                                                            },
                                                            child: Container(
                                                              alignment: Alignment.center,
                                                              decoration: BoxDecoration(color: Colors.tealAccent, borderRadius: BorderRadius.circular(2)),
                                                              child: const Text('[', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      // Draggable Right Handle
                                                      Positioned(
                                                        left: rRight - 6,
                                                        top: 0,
                                                        width: 12,
                                                        height: 22,
                                                        child: MouseRegion(
                                                          cursor: SystemMouseCursors.resizeLeftRight,
                                                          child: GestureDetector(
                                                            behavior: HitTestBehavior.opaque,
                                                            onHorizontalDragUpdate: (d) {
                                                              final deltaMs = ((d.delta.dx / pxPerSec) * 1000).round();
                                                              final cur = ref.read(exportRangeProvider).savedRanges[i];
                                                              final maxEnd = totalDurationMs > cur.startMs + 200 ? totalDurationMs : cur.startMs + 200;
                                                              final nextEnd = (cur.endMs + deltaMs).clamp(cur.startMs + 200, maxEnd);
                                                              rangeNotifier.updateSavedRange(i, cur.copyWith(endMs: nextEnd));
                                                            },
                                                            child: Container(
                                                              alignment: Alignment.center,
                                                              decoration: BoxDecoration(color: Colors.tealAccent, borderRadius: BorderRadius.circular(2)),
                                                              child: const Text(']', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ],
                                            // Active In/Out range
                                            if (hasBand)
                                              Positioned(
                                                left: leftX,
                                                top: 0,
                                                bottom: 0,
                                                width: (rightX - leftX).clamp(2.0, double.infinity),
                                                child: IgnorePointer(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: AppColors.exportGreen.withValues(alpha: 0.12),
                                                      border: const Border(
                                                        left: BorderSide(color: AppColors.exportGreen, width: 1.5),
                                                        right: BorderSide(color: AppColors.exportGreen, width: 1.5),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (inMs != null)
                                              Positioned(
                                                left: leftX - 6,
                                                top: 0,
                                                width: 12,
                                                height: 22,
                                                child: MouseRegion(
                                                  cursor: SystemMouseCursors.resizeLeftRight,
                                                  child: GestureDetector(
                                                    behavior: HitTestBehavior.opaque,
                                                    onHorizontalDragUpdate: (d) {
                                                      final deltaMs = ((d.delta.dx / pxPerSec) * 1000).round();
                                                      final curIn = ref.read(exportRangeProvider).inMs ?? 0;
                                                      final maxIn = (ref.read(exportRangeProvider).outMs ?? totalDurationMs) - 200;
                                                      final nextIn = (curIn + deltaMs).clamp(0, maxIn < 0 ? 0 : maxIn);
                                                      ref.read(exportRangeProvider.notifier).setInPoint(nextIn, totalDurationMs: totalDurationMs);
                                                    },
                                                    child: Container(
                                                      alignment: Alignment.center,
                                                      decoration: BoxDecoration(
                                                        color: AppColors.exportGreen,
                                                        borderRadius: BorderRadius.circular(2),
                                                      ),
                                                      child: const Text('[', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            if (outMs != null)
                                              Positioned(
                                                left: rightX - 6,
                                                top: 0,
                                                width: 12,
                                                height: 22,
                                                child: MouseRegion(
                                                  cursor: SystemMouseCursors.resizeLeftRight,
                                                  child: GestureDetector(
                                                    behavior: HitTestBehavior.opaque,
                                                    onHorizontalDragUpdate: (d) {
                                                      final deltaMs = ((d.delta.dx / pxPerSec) * 1000).round();
                                                      final curOut = ref.read(exportRangeProvider).outMs ?? totalDurationMs;
                                                      final minOut = (ref.read(exportRangeProvider).inMs ?? 0) + 200;
                                                      final nextOut = (curOut + deltaMs).clamp(minOut, totalDurationMs > minOut ? totalDurationMs : minOut);
                                                      ref.read(exportRangeProvider.notifier).setOutPoint(nextOut, totalDurationMs: totalDurationMs);
                                                    },
                                                    child: Container(
                                                      alignment: Alignment.center,
                                                      decoration: BoxDecoration(
                                                        color: AppColors.exportGreen,
                                                        borderRadius: BorderRadius.circular(2),
                                                      ),
                                                      child: const Text(']', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),

                                    // Active Magnetic Snap Guide Line
                                    Consumer(
                                      builder: (context, ref, _) {
                                        final snapMs = ref.watch(activeSnapLineMsProvider);
                                        if (snapMs == null) return const SizedBox.shrink();
                                        return Positioned(
                                          left: (snapMs / 1000) * pxPerSec,
                                          top: 0,
                                          bottom: 0,
                                          width: 1.5,
                                          child: IgnorePointer(
                                            child: Container(color: Colors.cyanAccent),
                                          ),
                                        );
                                      },
                                    ),

                                    Consumer(
                                      builder: (context, ref, _) {
                                        final curPlayheadMs = ref.watch(playheadPositionProvider);
                                        final playheadColor = ref.watch(themeProvider.select((t) => t.playheadColor));
                                        final curPlayheadX = (curPlayheadMs / 1000) * pxPerSec;
                                        return PlayheadNeedle(
                                          positionX: curPlayheadX,
                                          height: constraints.maxHeight,
                                          color: playheadColor,
                                          onDragStart: (d) => _handleNeedleDragStart(d, curPlayheadMs, pxPerSec),
                                          onDragUpdate: (d) => _handleNeedleDragUpdate(d, pxPerSec, totalDurationMs),
                                          onDragEnd: _handleNeedleDragEnd,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
