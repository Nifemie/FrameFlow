import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/timeline_track_item.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../services/playback_controller.dart';
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

  void _handleSeek(int ms) => ref.read(playbackControllerProvider).seek(ms);
  void _handleNeedleDragStart(DragStartDetails d, int ms, double pxPerSec) {
    ref.read(playbackControllerProvider).pause();
    _dragCurrentPlayheadX = (ms / 1000.0) * pxPerSec;
  }

  void _handleNeedleDragUpdate(DragUpdateDetails d, double pxPerSec, int totalMs) {
    _dragCurrentPlayheadX += d.delta.dx;
    final maxMs = max(totalMs, ref.read(projectProvider).totalDurationMs);
    ref.read(playbackControllerProvider).scrub(((_dragCurrentPlayheadX / pxPerSec) * 1000).round().clamp(0, maxMs));
    if (_scrollController.hasClients) {
      final off = _scrollController.offset, viewW = _scrollController.position.viewportDimension;
      if (_dragCurrentPlayheadX > off + viewW - 40) _scrollController.jumpTo((off + 15).clamp(0.0, _scrollController.position.maxScrollExtent));
      if (_dragCurrentPlayheadX < off + 40 && off > 0) _scrollController.jumpTo((off - 15).clamp(0.0, _scrollController.position.maxScrollExtent));
    }
  }

  void _handleNeedleDragEnd() {
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
    if (result != null) ref.read(projectProvider.notifier).addImages(result.paths.whereType<String>().toList(), trackId: trackId);
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
          ref.read(projectProvider.notifier).addImages(paths, trackId: trackId);
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

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          // Timeline Quick Control Bar: Zoom Slider & Fit to Project
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.surfaceBorder, width: 0.8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.view_timeline_rounded, size: 14, color: AppColors.accentOrange),
                const SizedBox(width: 6),
                const Text(
                  'TIMELINE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
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
                            Icon(Icons.vertical_align_center, size: 11, color: snapOn ? AppColors.accentOrange : AppColors.textMuted),
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bookmark_add_outlined, size: 11, color: Colors.amber),
                        SizedBox(width: 4),
                        Text('Mark (K)', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.format_align_left, size: 11, color: Colors.cyanAccent),
                        SizedBox(width: 4),
                        Text('Pack Left', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove, size: 14, color: AppColors.textSecondary),
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
                  icon: const Icon(Icons.add, size: 14, color: AppColors.textSecondary),
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fit_screen_rounded, size: 11, color: AppColors.accentOrange),
                        SizedBox(width: 4),
                        Text('Fit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
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
                                                    MediaTrackStrip(
                                                      images: project.imagesForTrack(tr.id),
                                                      contentWidth: contentWidth,
                                                      pxPerSec: pxPerSec,
                                                      zoom: zoom,
                                                      emptyLabel: '+ Add Images / Background to ${tr.name}',
                                                      onAdd: () => _pickImagesForTrack(tr.id),
                                                      onAddFolder: () => _pickFolderForTrack(tr.id),
                                                    ),
                                                    const SizedBox(height: 4),
                                                  ] else if (tr.type == TrackType.text) ...[
                                                    TextTimelineStrip(pxPerSec: pxPerSec, contentWidth: contentWidth),
                                                    const SizedBox(height: 4),
                                                  ] else if (tr.type == TrackType.audio) ...[
                                                    AudioWaveformStrip(pxPerSec: pxPerSec, contentWidth: contentWidth),
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
                                        final curPlayheadX = (curPlayheadMs / 1000) * pxPerSec;
                                        return PlayheadNeedle(
                                          positionX: curPlayheadX,
                                          height: constraints.maxHeight,
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
