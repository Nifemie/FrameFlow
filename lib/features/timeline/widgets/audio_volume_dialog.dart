import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';
import '../../../models/audio_clip_item.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../services/playback_controller.dart';

class AudioVolumeDialog extends ConsumerStatefulWidget {
  final AudioClipItem clip;

  const AudioVolumeDialog({super.key, required this.clip});

  @override
  ConsumerState<AudioVolumeDialog> createState() => _AudioVolumeDialogState();
}

class _AudioVolumeDialogState extends ConsumerState<AudioVolumeDialog> {
  late double _volume;
  late int _durationMs;

  @override
  void initState() {
    super.initState();
    _volume = widget.clip.volume;
    _durationMs = widget.clip.durationMs;
  }

  void _adjustTrim(int deltaMs) {
    final newDur = (_durationMs + deltaMs).clamp(500, 3600000);
    setState(() => _durationMs = newDur);
    ref.read(projectProvider.notifier).trimAudioClip(widget.clip.id, newDur);
  }

  @override
  Widget build(BuildContext context) {
    final playheadMs = ref.watch(playheadPositionProvider);
    final canSplit = playheadMs > widget.clip.startTimelineMs + 100 &&
        playheadMs < widget.clip.startTimelineMs + _durationMs - 100;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Row(
        children: [
          const Icon(Icons.audiotrack, color: AppColors.waveform, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.clip.fileName,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Volume Level', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                Text('${(_volume * 100).round()}%',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.waveform)),
              ],
            ),
            Slider(
              value: _volume,
              min: 0.0,
              max: 1.5,
              divisions: 30,
              activeColor: AppColors.waveform,
              inactiveColor: AppColors.surfaceBorder,
              onChanged: (val) {
                setState(() => _volume = val);
                ref.read(projectProvider.notifier).setAudioClipVolume(widget.clip.id, val);
                ref.read(playbackControllerProvider).setLiveVolume(val);
              },
            ),
            const Divider(color: AppColors.surfaceBorder, height: 16),
            const Text('Trim Duration', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '${TimeParser.formatStandard(_durationMs)} (${(_durationMs / 1000).toStringAsFixed(1)}s)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
                const Spacer(),
                _trimBtn('-1s', () => _adjustTrim(-1000)),
                const SizedBox(width: 4),
                _trimBtn('-0.5s', () => _adjustTrim(-500)),
                const SizedBox(width: 4),
                _trimBtn('+0.5s', () => _adjustTrim(500)),
                const SizedBox(width: 4),
                _trimBtn('+1s', () => _adjustTrim(1000)),
              ],
            ),
            if (canSplit) ...[
              const Divider(color: AppColors.surfaceBorder, height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.waveform,
                    side: const BorderSide(color: AppColors.waveform),
                  ),
                  icon: const Icon(Icons.call_split, size: 16),
                  label: Text('Split at Playhead (${TimeParser.formatStandard(playheadMs)})'),
                  onPressed: () {
                    ref.read(projectProvider.notifier).splitAudioAtPlayhead(playheadMs);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
            const Divider(color: AppColors.surfaceBorder, height: 16),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete Audio Track'),
                onPressed: () {
                  ref.read(playbackControllerProvider).stopAudioIfActive(widget.clip.id);
                  ref.read(projectProvider.notifier).deleteAudioClip(widget.clip.id);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _trimBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ),
    );
  }
}
