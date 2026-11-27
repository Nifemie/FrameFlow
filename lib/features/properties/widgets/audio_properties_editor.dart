import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';
import '../../../models/audio_clip_item.dart';
import '../../../models/timeline_track_item.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import 'audio_range_dialog.dart';
import '../../../services/playback_controller.dart';
import '../../../services/video_playback_engine.dart';
import '../../timestamps/widgets/bulk_timestamp_dialog.dart';

class AudioPropertiesEditor extends ConsumerWidget {
  final AudioClipItem clip;

  const AudioPropertiesEditor({super.key, required this.clip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playheadMs = ref.watch(playheadPositionProvider);
    final project = ref.watch(projectProvider);
    final canSplit = playheadMs > clip.startTimelineMs + 100 && playheadMs < clip.endTimelineMs - 100;
    final isClipMuted = clip.volume == 0.0 || project.isAudioMuted;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.music_note, size: 16, color: AppColors.waveform),
                  SizedBox(width: 6),
                  Text(
                    'Audio Clip',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 14, color: AppColors.textSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => ref.read(selectedAudioClipIdProvider.notifier).state = null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            clip.fileName,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.surfaceBorder),
          const SizedBox(height: 14),

          // Timing & Timestamp Section
          const Text('TIMING & TIMESTAMPS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          _AudioTimestampEditor(clip: clip),
          const SizedBox(height: 10),

          // Bulk Timestamps Dialog Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentOrange,
                side: BorderSide(color: AppColors.accentOrange.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(vertical: 7),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              icon: const Icon(Icons.playlist_add_check, size: 15, color: AppColors.accentOrange),
              label: const Text(
                'Bulk Timestamps / CSV...',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const BulkTimestampDialog(
                  trackName: 'Audio Track',
                  isAudio: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Quick Alignment buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    side: const BorderSide(color: AppColors.surfaceBorder),
                  ),
                  onPressed: () {
                    ref.read(projectProvider.notifier).moveAudioClipStart(clip.id, 0);
                  },
                  child: const Text('Start at 00:00', style: TextStyle(fontSize: 10, color: Colors.white70)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    side: const BorderSide(color: AppColors.surfaceBorder),
                  ),
                  onPressed: () {
                    ref.read(projectProvider.notifier).moveAudioClipStart(clip.id, playheadMs);
                  },
                  child: const Text('Snap to Playhead', style: TextStyle(fontSize: 10, color: Colors.white70)),
                ),
              ),
            ],
          ),
          if (project.images.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 30,
              child: PopupMenuButton<int>(
                tooltip: 'Snap this audio to start at a specific image',
                color: AppColors.surface,
                offset: const Offset(0, 32),
                onSelected: (targetMs) {
                  ref.read(projectProvider.notifier).moveAudioClipStart(clip.id, targetMs);
                },
                itemBuilder: (ctx) => [
                  for (final img in project.images)
                    PopupMenuItem<int>(
                      value: img.startMs,
                      child: Row(
                        children: [
                          Icon(img.isVideo ? Icons.movie : Icons.image, size: 13, color: AppColors.accentOrange),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Clip #${img.orderIndex + 1}: ${img.displayName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            TimeParser.formatStandard(img.startMs),
                            style: const TextStyle(fontSize: 10, color: AppColors.accentOrange, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.6), width: 0.8),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined, size: 12, color: AppColors.accentOrange),
                      SizedBox(width: 6),
                      Text(
                        'Align to Image in Timeline...',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.accentOrange),
                      ),
                      Spacer(),
                      Icon(Icons.arrow_drop_down, size: 16, color: AppColors.accentOrange),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 6),
          // Nudge buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    side: const BorderSide(color: AppColors.surfaceBorder),
                  ),
                  onPressed: () {
                    final target = max(0, clip.startTimelineMs - 1000);
                    ref.read(projectProvider.notifier).moveAudioClipStart(clip.id, target);
                  },
                  child: const Text('◀ -1s', style: TextStyle(fontSize: 10, color: Colors.white70)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    side: const BorderSide(color: AppColors.surfaceBorder),
                  ),
                  onPressed: () {
                    final target = clip.startTimelineMs + 1000;
                    ref.read(projectProvider.notifier).moveAudioClipStart(clip.id, target);
                  },
                  child: const Text('+1s ▶', style: TextStyle(fontSize: 10, color: Colors.white70)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.surfaceBorder),
          const SizedBox(height: 14),

          // Volume & Mute Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('AUDIO PLAYBACK & VOLUME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.8)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isClipMuted ? AppColors.errorRed.withValues(alpha: 0.15) : AppColors.waveform.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isClipMuted ? AppColors.errorRed.withValues(alpha: 0.5) : AppColors.waveform.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  isClipMuted ? 'MUTED' : '${(clip.volume * 100).round()}%',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isClipMuted ? AppColors.errorRed : AppColors.waveform,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Primary Mute Button
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isClipMuted
                    ? AppColors.errorRed.withValues(alpha: 0.2)
                    : AppColors.surfaceLight,
                foregroundColor: isClipMuted ? AppColors.errorRed : Colors.white,
                side: BorderSide(
                  color: isClipMuted ? AppColors.errorRed : AppColors.accentOrange,
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
              icon: Icon(
                isClipMuted ? Icons.volume_off : Icons.volume_up,
                size: 16,
                color: isClipMuted ? AppColors.errorRed : AppColors.accentOrange,
              ),
              label: Text(
                isClipMuted ? 'Muted (Click to Unmute)' : 'Mute Audio',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isClipMuted ? AppColors.errorRed : Colors.white,
                ),
              ),
              onPressed: () {
                if (isClipMuted) {
                  // Restore volume and unmute track
                  ref.read(projectProvider.notifier).setAudioClipVolume(clip.id, 1.0);
                  if (project.isAudioMuted) {
                    final audioTracks = project.effectiveTracks.where((t) => t.type == TrackType.audio);
                    for (final tr in audioTracks) {
                      if (tr.isMuted) ref.read(projectProvider.notifier).toggleTrackMute(tr.id);
                    }
                  }
                  ref.read(playbackControllerProvider).setLiveVolume(1.0);
                  VideoPlaybackEngine.setVolume(100.0);
                } else {
                  // Mute clip volume and track
                  ref.read(projectProvider.notifier).setAudioClipVolume(clip.id, 0.0);
                  ref.read(playbackControllerProvider).setLiveVolume(0.0);
                  VideoPlaybackEngine.setVolume(0.0);
                }
              },
            ),
          ),
          const SizedBox(height: 10),

          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: isClipMuted ? AppColors.textMuted : AppColors.waveform,
              inactiveTrackColor: AppColors.surfaceBorder,
              thumbColor: isClipMuted ? AppColors.textMuted : AppColors.waveform,
              overlayColor: AppColors.waveform.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: clip.volume.clamp(0.0, 2.0),
              min: 0.0,
              max: 2.0,
              divisions: 40,
              onChanged: (val) {
                ref.read(projectProvider.notifier).setAudioClipVolume(clip.id, val);
                ref.read(playbackControllerProvider).setLiveVolume(val);
              },
            ),
          ),
          const SizedBox(height: 4),
          // Quick Volume Presets (Reduce / Boost)
          Row(
            children: [
              _buildVolPreset(ref, 'Mute', 0.0),
              const SizedBox(width: 4),
              _buildVolPreset(ref, '25%', 0.25),
              const SizedBox(width: 4),
              _buildVolPreset(ref, '50%', 0.5),
              const SizedBox(width: 4),
              _buildVolPreset(ref, '100%', 1.0),
              const SizedBox(width: 4),
              _buildVolPreset(ref, '150%', 1.5),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.surfaceBorder),
          const SizedBox(height: 14),

          // Audio Source Range (In - Out)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Audio Source Range', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.waveform)),
                    if (clip.sourceDurationMs != null && clip.sourceDurationMs! > 0)
                      Text(
                        'Total: ${TimeParser.formatStandard(clip.sourceDurationMs!)}',
                        style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${TimeParser.formatStandard(clip.fileStartOffsetMs)} → ${TimeParser.formatStandard(clip.fileStartOffsetMs + clip.durationMs)}',
                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 28,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      side: const BorderSide(color: AppColors.accentOrange),
                    ),
                    icon: const Icon(Icons.graphic_eq, size: 13, color: AppColors.accentOrange),
                    label: const Text('Cut / Set Range (In - Out)', style: TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () => showDialog(context: context, builder: (_) => AudioRangeDialog(clip: clip)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.surfaceBorder),
          const SizedBox(height: 14),

          // Split & Cut Operations
          const Text('SPLIT & EDIT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    backgroundColor: canSplit ? AppColors.clipBlue.withValues(alpha: 0.15) : null,
                    side: BorderSide(color: canSplit ? AppColors.clipBlue : AppColors.surfaceBorder),
                  ),
                  icon: const Icon(Icons.content_cut, size: 13, color: AppColors.clipBlueLight),
                  label: Text(
                    canSplit ? 'Split at Playhead (S)' : 'Move Playhead & Split',
                    style: const TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    if (canSplit) {
                      ref.read(projectProvider.notifier).splitAudioAtPlayhead(playheadMs);
                    } else {
                      final mid = clip.startTimelineMs + (clip.durationMs ~/ 2);
                      ref.read(projectProvider.notifier).splitSpecificAudioClip(clip.id, atTimelineMs: mid);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    side: const BorderSide(color: AppColors.surfaceBorder),
                  ),
                  icon: const Icon(Icons.call_split, size: 13, color: AppColors.textSecondary),
                  label: const Text('Split in Half (50/50)', style: TextStyle(fontSize: 10.5, color: Colors.white70)),
                  onPressed: () {
                    ref.read(projectProvider.notifier).splitSpecificAudioClip(clip.id);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.surfaceBorder),
          const SizedBox(height: 14),

          // Delete Action
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                side: BorderSide(color: AppColors.errorRed.withValues(alpha: 0.6)),
              ),
              icon: const Icon(Icons.delete_outline, size: 14, color: AppColors.errorRed),
              label: const Text('Delete Audio Clip (Del)', style: TextStyle(fontSize: 11, color: AppColors.errorRed, fontWeight: FontWeight.bold)),
              onPressed: () {
                ref.read(projectProvider.notifier).deleteAudioClip(clip.id);
                ref.read(selectedAudioClipIdProvider.notifier).state = null;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolPreset(WidgetRef ref, String label, double vol) {
    final isCurrent = (clip.volume - vol).abs() < 0.04;
    return Expanded(
      child: InkWell(
        onTap: () => ref.read(projectProvider.notifier).setAudioClipVolume(clip.id, vol),
        borderRadius: BorderRadius.circular(3),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCurrent ? AppColors.waveform.withValues(alpha: 0.3) : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: isCurrent ? AppColors.waveform : AppColors.surfaceBorder,
              width: isCurrent ? 1.0 : 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent ? AppColors.waveform : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioTimestampEditor extends ConsumerStatefulWidget {
  final AudioClipItem clip;

  const _AudioTimestampEditor({required this.clip});

  @override
  ConsumerState<_AudioTimestampEditor> createState() => _AudioTimestampEditorState();
}

class _AudioTimestampEditorState extends ConsumerState<_AudioTimestampEditor> {
  late TextEditingController _startCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCtrl = TextEditingController(text: TimeParser.formatStandard(widget.clip.startTimelineMs));
  }

  @override
  void didUpdateWidget(covariant _AudioTimestampEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clip.id != widget.clip.id ||
        oldWidget.clip.startTimelineMs != widget.clip.startTimelineMs) {
      _startCtrl.text = TimeParser.formatStandard(widget.clip.startTimelineMs);
      _error = null;
    }
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    super.dispose();
  }

  void _submitStart(String val) {
    final parsedMs = TimeParser.parseToMs(val.trim());
    if (parsedMs == null) {
      setState(() => _error = 'Invalid timestamp format (e.g. 00:15 or 1:20)');
      return;
    }
    setState(() => _error = null);
    ref.read(projectProvider.notifier).moveAudioClipStart(widget.clip.id, parsedMs);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Start Timestamp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              Text(
                'End: ${TimeParser.formatStandard(widget.clip.endTimelineMs)}',
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _startCtrl,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.background,
                      hintText: '00:00.000',
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.surfaceBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.surfaceBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.accentOrange, width: 1.2)),
                    ),
                    onSubmitted: _submitStart,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () => _submitStart(_startCtrl.text),
                  child: const Text('Set', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: const TextStyle(fontSize: 10, color: AppColors.errorRed)),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Duration', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
              Text(TimeParser.formatDetailed(widget.clip.durationMs), style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          if (widget.clip.fileStartOffsetMs > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Source Offset', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                Text(TimeParser.formatDetailed(widget.clip.fileStartOffsetMs), style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
