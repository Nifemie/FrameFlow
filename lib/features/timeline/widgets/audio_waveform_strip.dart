import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';
import '../../../models/audio_clip_item.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../services/audio_probe_service.dart';
import '../../../services/timeline_arrangement_service.dart';
import 'asset_context_menus.dart';
import 'audio_volume_dialog.dart';

class AudioWaveformStrip extends ConsumerWidget {
  final double pxPerSec;
  final double contentWidth;
  const AudioWaveformStrip({
    super.key,
    required this.pxPerSec,
    required this.contentWidth,
  });

  Future<void> _pickAudio(BuildContext context, WidgetRef ref, {int? explicitStartMs}) async {
    final playheadMs = ref.read(playheadPositionProvider);
    final clips = ref.read(projectProvider).effectiveAudioClips;
    final lastEnd = clips.isNotEmpty ? clips.last.endTimelineMs : 0;
    int? customStart = explicitStartMs;

    if (customStart == null && clips.isNotEmpty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text('Add Audio Track Placement', style: TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(dense: true, leading: const Icon(Icons.vertical_align_center, color: AppColors.playheadNeedle, size: 18), title: Text('Start at Playhead (${TimeParser.formatStandard(playheadMs)})', style: const TextStyle(fontSize: 12, color: Colors.white)), subtitle: const Text('Leaves silent gap before track', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)), onTap: () => Navigator.pop(ctx, 'playhead')),
              ListTile(dense: true, leading: const Icon(Icons.fast_forward, color: AppColors.waveform, size: 18), title: Text('Snap after previous (${TimeParser.formatStandard(lastEnd)})', style: const TextStyle(fontSize: 12, color: Colors.white)), subtitle: const Text('Continuous audio without gap', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)), onTap: () => Navigator.pop(ctx, 'append')),
            ],
          ),
        ),
      );
      if (choice == null) return;
      if (choice == 'playhead') customStart = playheadMs;
    }

    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg'], dialogTitle: 'Select Audio Track');
    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!, name = result.files.single.name;
      final dur = await AudioProbeService.getAudioDurationMs(path);
      if (dur > 0) {
        ref.read(projectProvider.notifier).addAudioClip(path, name, dur, customStartMs: customStart);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎵 Added "$name"${customStart != null ? ' at ${TimeParser.formatStandard(customStart)}' : ''}!')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    final clips = project.effectiveAudioClips;
    if (clips.isEmpty) {
      return SizedBox(
        width: contentWidth,
        height: 38,
        child: Container(
          decoration: BoxDecoration(color: AppColors.surfaceLight.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.surfaceBorder, width: 0.8)),
          child: Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentOrange,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              ),
              onPressed: () => _pickAudio(context, ref),
              icon: const Icon(Icons.music_note, size: 14, color: AppColors.accentOrange),
              label: const Text(
                '+ Add Audio Track / Music',
                style: TextStyle(fontSize: 10.5, color: AppColors.accentOrange, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      );
    }
    final lastEnd = clips.map((c) => c.endTimelineMs).reduce((a, b) => a > b ? a : b);
    final playheadMs = ref.watch(playheadPositionProvider);

    return SizedBox(
      width: contentWidth,
      height: 38,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ...clips.map((clip) => _AudioClipCard(
                key: ValueKey(clip.id),
                clip: clip,
                pxPerSec: pxPerSec,
                snapPointsMs: <int>{
                  0,
                  playheadMs,
                  ...project.images.map((i) => i.startMs),
                  ...project.images.map((i) => i.endMs),
                  ...clips.where((c) => c.id != clip.id).map((c) => c.startTimelineMs),
                  ...clips.where((c) => c.id != clip.id).map((c) => c.endTimelineMs),
                }.toList(),
              )),
          Positioned(
            left: (lastEnd / 1000) * pxPerSec + 4, top: 7,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.surfaceLight, foregroundColor: AppColors.waveform, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: const Size(0, 24), side: const BorderSide(color: AppColors.waveform)),
                  icon: const Icon(Icons.add, size: 12),
                  label: const Text('Add Audio', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  onPressed: () => _pickAudio(context, ref),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Snap last clip to audio ending',
                  icon: const Icon(Icons.vertical_align_bottom, size: 14, color: AppColors.waveform),
                  onPressed: () { final img = ref.read(projectProvider).images; if (img.isNotEmpty) ref.read(projectProvider.notifier).snapClipToAudio(img.last.id); },
                ),
              ],
            ),
          ),
          Consumer(
            builder: (context, ref, _) {
              final isPlaying = ref.watch(isPlayingProvider);
              if (isPlaying) return const SizedBox.shrink();
              final playheadMs = ref.watch(playheadPositionProvider);
              if (playheadMs <= lastEnd + 200) return const SizedBox.shrink();
              return Positioned(
                left: (playheadMs / 1000) * pxPerSec + 2,
                top: 7,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surfaceLight.withValues(alpha: 0.8),
                    foregroundColor: AppColors.playheadNeedle,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    minimumSize: const Size(0, 24),
                    side: const BorderSide(color: AppColors.playheadNeedle),
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 11, color: AppColors.playheadNeedle),
                  label: Text(
                    'Add at ${TimeParser.formatStandard(playheadMs)}',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.playheadNeedle),
                  ),
                  onPressed: () => _pickAudio(context, ref, explicitStartMs: playheadMs),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final String fileName;
  final List<double>? peaks;
  final int fileStartOffsetMs;
  final int durationMs;
  final double volume;

  _WaveformPainter({
    required this.fileName,
    this.peaks,
    this.fileStartOffsetMs = 0,
    this.durationMs = 0,
    this.volume = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barPaint = Paint()..color = AppColors.waveform.withValues(alpha: 0.85)..strokeWidth = 2.0..strokeCap = StrokeCap.round;
    final centerY = size.height / 2;
    const barSpacing = 3.0;
    final barCount = max(1, (size.width / barSpacing).floor());
    final maxHalfHeight = size.height / 2 - 3;

    if (peaks != null && peaks!.isNotEmpty && durationMs > 0) {
      final totalBins = peaks!.length;
      const binsPerSec = AudioProbeService.waveformBinsPerSecond;
      for (int i = 0; i < barCount; i++) {
        final x = i * barSpacing + 1.5;
        final tMs = fileStartOffsetMs + ((i + 0.5) / barCount) * durationMs;
        final binIdx = ((tMs * binsPerSec) / 1000.0).floor().clamp(0, totalBins - 1);
        final amp = (peaks![binIdx] * volume.clamp(0.0, 1.5)).clamp(0.03, 1.0) * maxHalfHeight;
        canvas.drawLine(Offset(x, centerY - amp), Offset(x, centerY + amp), barPaint);
      }
    } else {
      // Subtle baseline while real PCM peaks are decoding
      final flatPaint = Paint()..color = AppColors.waveform.withValues(alpha: 0.35)..strokeWidth = 1.2;
      canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), flatPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) =>
      old.fileName != fileName ||
      old.peaks != peaks ||
      old.fileStartOffsetMs != fileStartOffsetMs ||
      old.durationMs != durationMs ||
      old.volume != volume;
}

class _AudioClipCard extends ConsumerStatefulWidget {
  final AudioClipItem clip;
  final double pxPerSec;
  final List<int> snapPointsMs;

  const _AudioClipCard({
    super.key,
    required this.clip,
    required this.pxPerSec,
    required this.snapPointsMs,
  });

  @override
  ConsumerState<_AudioClipCard> createState() => _AudioClipCardState();
}

class _AudioClipCardState extends ConsumerState<_AudioClipCard> {
  double _dragStartGlobalX = 0;
  double _leftTrimStartGlobalX = 0;
  double _rightTrimStartGlobalX = 0;
  int _initialStartMs = 0;
  int _currentDragStartMs = 0;
  int _initialDurationMs = 0;
  int _currentTrimEndDurMs = 0;
  int _currentTrimStartMs = 0;
  bool _isHovered = false;
  bool _isDragging = false;
  bool _isLeftTrimHovered = false;
  bool _isRightTrimHovered = false;

  int _snapToNearest(int valueMs, {int thresholdMs = 150}) {
    if (!ref.read(snappingEnabledProvider)) {
      ref.read(activeSnapLineMsProvider.notifier).state = null;
      return valueMs;
    }
    final (snapped, line) = TimelineArrangementService.snapToTargets(
      targetMs: valueMs,
      targets: widget.snapPointsMs,
      pxPerSec: widget.pxPerSec,
      enabled: true,
    );
    ref.read(activeSnapLineMsProvider.notifier).state = line;
    return snapped;
  }

  void _selectThisClip() {
    SelectionHelper.selectAudioClip(ref, widget.clip.id);
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.clip;
    final selectedId = ref.watch(selectedAudioClipIdProvider);
    final isSelected = selectedId == clip.id;
    final playheadMs = ref.watch(playheadPositionProvider);
    final canSplit = playheadMs > clip.startTimelineMs + 100 && playheadMs < clip.endTimelineMs - 100;

    final left = (clip.startTimelineMs / 1000) * widget.pxPerSec;
    final width = max(50.0, (clip.durationMs / 1000) * widget.pxPerSec);
    final isHoveredOrSelected = _isHovered || isSelected;

    final playheadOffset = ((playheadMs - clip.startTimelineMs) / 1000) * widget.pxPerSec;

    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      width: width,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Full-Clip Draggable Body
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _selectThisClip,
                onSecondaryTapUp: (details) => AssetContextMenus.showAudioClipMenu(
                  context: context,
                  ref: ref,
                  globalPosition: details.globalPosition,
                  clip: clip,
                ),
                onDoubleTap: () => showDialog(context: context, builder: (_) => AudioVolumeDialog(clip: clip)),
                onHorizontalDragStart: (details) {
                  ref.read(projectProvider.notifier).recordSnapshot();
                  setState(() => _isDragging = true);
                  _dragStartGlobalX = details.globalPosition.dx;
                  _initialStartMs = clip.startTimelineMs;
                  _currentDragStartMs = clip.startTimelineMs;
                  _selectThisClip();
                },
                onHorizontalDragUpdate: (details) {
                  final deltaX = details.globalPosition.dx - _dragStartGlobalX;
                  final deltaMs = ((deltaX / widget.pxPerSec) * 1000).round();
                  int targetMs = max(0, _initialStartMs + deltaMs);
                  targetMs = _snapToNearest(targetMs, thresholdMs: 150);
                  if (targetMs != _currentDragStartMs) {
                    _currentDragStartMs = targetMs;
                    ref.read(projectProvider.notifier).moveAudioClipStart(clip.id, targetMs, recordUndo: false);
                  }
                },
                onHorizontalDragEnd: (_) {
                  setState(() => _isDragging = false);
                  ref.read(activeSnapLineMsProvider.notifier).state = null;
                },
                onHorizontalDragCancel: () {
                  setState(() => _isDragging = false);
                  ref.read(activeSnapLineMsProvider.notifier).state = null;
                },
                child: MouseRegion(
                  cursor: _isDragging ? SystemMouseCursors.grabbing : SystemMouseCursors.grab,
                  child: Container(
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accentOrange
                            : (_isHovered ? Colors.white38 : AppColors.surfaceBorder),
                        width: isSelected ? 2.2 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.accentOrange.withValues(alpha: 0.65),
                                blurRadius: 8,
                                spreadRadius: 1.5,
                              ),
                              const BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2)),
                            ]
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        // Waveform Canvas (real PCM peaks)
                        Positioned.fill(
                          child: Builder(
                            builder: (context) {
                              final peaks = AudioProbeService.getCachedWaveformPeaks(clip.filePath);
                              if (peaks == null) {
                                AudioProbeService.getWaveformPeaks(clip.filePath).then((p) {
                                  if (p != null && mounted) setState(() {});
                                });
                              }
                              return Opacity(
                                opacity: isSelected ? 1.0 : 0.8,
                                child: CustomPaint(
                                  size: Size(width, 36),
                                  painter: _WaveformPainter(
                                    fileName: clip.fileName,
                                    peaks: peaks,
                                    fileStartOffsetMs: clip.fileStartOffsetMs,
                                    durationMs: clip.durationMs,
                                    volume: clip.volume,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Audio Clip Badge & Info (wrapped in IgnorePointer so entire card responds to drag/click)
                        Positioned(
                          left: 12,
                          top: 6,
                          child: IgnorePointer(
                            ignoring: true,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Order badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.accentOrange : const Color(0xFF6B21A8),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.music_note, size: 9, color: Colors.white),
                                      const SizedBox(width: 2),
                                      Text(
                                        '#${clip.orderIndex + 1}',
                                        style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  constraints: BoxConstraints(maxWidth: max(35.0, width - 95.0)),
                                  child: Text(
                                    clip.fileName,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? Colors.white : Colors.white70,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Volume Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: clip.volume == 0 ? AppColors.errorRed : AppColors.waveform,
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    clip.volume == 0 ? 'MUTED' : '${(clip.volume * 100).round()}%',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: clip.volume == 0 ? AppColors.errorRed : AppColors.waveform,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 2. Playhead Inline Split Cut Button
            if (canSplit && width > 40 && playheadOffset >= 14 && playheadOffset <= width - 14)
              Positioned(
                left: playheadOffset - 9,
                top: 9,
                child: Tooltip(
                  message: 'Split Audio at Playhead (S)',
                  child: InkWell(
                    onTap: () => ref.read(projectProvider.notifier).splitAudioAtPlayhead(playheadMs),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.clipBlueLight, width: 1.5),
                        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))],
                      ),
                      child: const Center(
                        child: Icon(Icons.content_cut, size: 10, color: AppColors.clipBlueLight),
                      ),
                    ),
                  ),
                ),
              ),

            // 3. Left White Trim Handle (Trims Audio Start / Source Offset)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 14,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                onEnter: (_) => setState(() => _isLeftTrimHovered = true),
                onExit: (_) => setState(() => _isLeftTrimHovered = false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) {
                    _leftTrimStartGlobalX = details.globalPosition.dx;
                    _initialStartMs = clip.startTimelineMs;
                    _currentTrimStartMs = clip.startTimelineMs;
                    _selectThisClip();
                  },
                  onHorizontalDragUpdate: (details) {
                    final deltaX = details.globalPosition.dx - _leftTrimStartGlobalX;
                    final deltaMs = ((deltaX / widget.pxPerSec) * 1000).round();
                    int targetMs = _initialStartMs + deltaMs;
                    targetMs = _snapToNearest(targetMs, thresholdMs: 150);
                    if (targetMs != _currentTrimStartMs) {
                      _currentTrimStartMs = targetMs;
                      ref.read(projectProvider.notifier).trimAudioClipStart(clip.id, targetMs, recordUndo: false);
                    }
                  },
                  onHorizontalDragEnd: (_) {
                    ref.read(projectProvider.notifier).trimAudioClipStart(clip.id, _currentTrimStartMs, recordUndo: true);
                  },
                  child: Container(
                    width: 14,
                    color: _isLeftTrimHovered ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: (isHoveredOrSelected || _isLeftTrimHovered) ? 1.0 : 0.35,
                        child: Container(
                          width: 3,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(1.5),
                            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 2.5)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 4. Right White Trim Handle (Trims Audio End / Duration)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 14,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                onEnter: (_) => setState(() => _isRightTrimHovered = true),
                onExit: (_) => setState(() => _isRightTrimHovered = false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (details) {
                    _rightTrimStartGlobalX = details.globalPosition.dx;
                    _initialDurationMs = clip.durationMs;
                    _currentTrimEndDurMs = clip.durationMs;
                    _selectThisClip();
                  },
                  onHorizontalDragUpdate: (details) {
                    final deltaX = details.globalPosition.dx - _rightTrimStartGlobalX;
                    final deltaMs = ((deltaX / widget.pxPerSec) * 1000).round();
                    int targetDur = _initialDurationMs + deltaMs;
                    final targetEndMs = _snapToNearest(clip.startTimelineMs + targetDur, thresholdMs: 150);
                    targetDur = targetEndMs - clip.startTimelineMs;
                    if (targetDur != _currentTrimEndDurMs) {
                      _currentTrimEndDurMs = targetDur;
                      ref.read(projectProvider.notifier).trimAudioClipEnd(clip.id, targetDur, recordUndo: false);
                    }
                  },
                  onHorizontalDragEnd: (_) {
                    ref.read(projectProvider.notifier).trimAudioClipEnd(clip.id, _currentTrimEndDurMs, recordUndo: true);
                  },
                  child: Container(
                    width: 14,
                    color: _isRightTrimHovered ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: (isHoveredOrSelected || _isRightTrimHovered) ? 1.0 : 0.35,
                        child: Container(
                          width: 3,
                          height: 22,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(1.5),
                            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 2.5)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 5. Side Circular Action Button (Split / Audio Options on clip edge)
            if (isHoveredOrSelected)
              Positioned(
                right: -9,
                top: 9,
                child: _AudioSideSplitButton(clip: clip),
              ),
          ],
        ),
      ),
    );
  }
}

class _AudioSideSplitButton extends ConsumerWidget {
  final AudioClipItem clip;
  const _AudioSideSplitButton({required this.clip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playheadMs = ref.watch(playheadPositionProvider);
    final isPlayheadInside = playheadMs > clip.startTimelineMs + 100 && playheadMs < clip.endTimelineMs - 100;

    return PopupMenuButton<String>(
      tooltip: isPlayheadInside
          ? 'Split Audio at Playhead (${TimeParser.formatStandard(playheadMs)})'
          : 'Split / Audio Options',
      padding: EdgeInsets.zero,
      color: AppColors.surface,
      offset: const Offset(0, 22),
      onSelected: (val) {
        if (val == 'split_playhead') {
          ref.read(projectProvider.notifier).splitAudioAtPlayhead(playheadMs);
        } else if (val == 'split_half') {
          ref.read(projectProvider.notifier).splitSpecificAudioClip(clip.id);
        } else if (val == 'volume') {
          showDialog(context: context, builder: (_) => AudioVolumeDialog(clip: clip));
        } else if (val == 'delete') {
          ref.read(projectProvider.notifier).deleteAudioClip(clip.id);
          ref.read(selectedAudioClipIdProvider.notifier).state = null;
        }
      },
      itemBuilder: (_) => [
        if (isPlayheadInside)
          PopupMenuItem(
            value: 'split_playhead',
            child: Row(
              children: [
                const Icon(Icons.content_cut, size: 14, color: AppColors.accentOrange),
                const SizedBox(width: 8),
                Text('Split at Playhead (${TimeParser.formatStandard(playheadMs)})', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        const PopupMenuItem(
          value: 'split_half',
          child: Row(
            children: [
              Icon(Icons.call_split, size: 14, color: AppColors.clipBlueLight),
              SizedBox(width: 8),
              Text('Split in Half (50/50)', style: TextStyle(fontSize: 11, color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'volume',
          child: Row(
            children: [
              Icon(Icons.volume_up, size: 14, color: AppColors.waveform),
              SizedBox(width: 8),
              Text('Adjust Volume / Reduce Sound', style: TextStyle(fontSize: 11, color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 14, color: AppColors.errorRed),
              SizedBox(width: 8),
              Text('Delete Audio Clip', style: TextStyle(fontSize: 11, color: AppColors.errorRed)),
            ],
          ),
        ),
      ],
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: const Center(
          child: Icon(Icons.content_cut, size: 10, color: Colors.white),
        ),
      ),
    );
  }
}
