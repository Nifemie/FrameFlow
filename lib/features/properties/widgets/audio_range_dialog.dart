import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';
import '../../../models/audio_clip_item.dart';
import '../../../providers/project_provider.dart';

/// Dialog for cutting and selecting an exact source time range [In..Out] from an audio clip.
/// Example: selecting 05:00 to 08:00 from a 10:00 audio file results in a 03:00 timeline clip.
class AudioRangeDialog extends ConsumerStatefulWidget {
  final AudioClipItem clip;

  const AudioRangeDialog({super.key, required this.clip});

  @override
  ConsumerState<AudioRangeDialog> createState() => _AudioRangeDialogState();
}

class _AudioRangeDialogState extends ConsumerState<AudioRangeDialog> {
  late TextEditingController _startCtrl;
  late TextEditingController _endCtrl;
  String? _error;

  @override
  void initState() {
    super.initState();
    final startMs = widget.clip.fileStartOffsetMs;
    final endMs = startMs + widget.clip.durationMs;
    _startCtrl = TextEditingController(text: TimeParser.formatStandard(startMs));
    _endCtrl = TextEditingController(text: TimeParser.formatStandard(endMs));
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  int? get _parsedStart => TimeParser.parseToMs(_startCtrl.text);
  int? get _parsedEnd => TimeParser.parseToMs(_endCtrl.text);

  void _apply() {
    final start = _parsedStart;
    final end = _parsedEnd;
    if (start == null || end == null) {
      setState(() => _error = 'Enter valid timestamps (e.g. 05:00 or 05:00.500)');
      return;
    }
    if (end <= start + 200) {
      setState(() => _error = 'End time must be at least 0.2s after Start time');
      return;
    }
    final maxDur = widget.clip.sourceDurationMs;
    if (maxDur != null && maxDur > 0 && end > maxDur) {
      setState(() => _error = 'End time exceeds audio length (${TimeParser.formatStandard(maxDur)})');
      return;
    }
    ref.read(projectProvider.notifier).updateAudioSourceRange(widget.clip.id, start, end);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final totalSource = widget.clip.sourceDurationMs;
    final s = _parsedStart;
    final e = _parsedEnd;
    final previewDurMs = (s != null && e != null && e > s) ? (e - s) : null;

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Row(
        children: [
          Icon(Icons.graphic_eq, size: 18, color: AppColors.waveform),
          SizedBox(width: 8),
          Text('Set Audio Source Range', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.clip.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            if (totalSource != null && totalSource > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Total audio length: ${TimeParser.formatStandard(totalSource)}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startCtrl,
                    onChanged: (_) => setState(() => _error = null),
                    style: const TextStyle(fontFamily: 'Consolas', fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Start (In)',
                      labelStyle: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      hintText: '05:00',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 16, color: AppColors.textMuted),
                ),
                Expanded(
                  child: TextField(
                    controller: _endCtrl,
                    onChanged: (_) => setState(() => _error = null),
                    style: const TextStyle(fontFamily: 'Consolas', fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'End (Out)',
                      labelStyle: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      hintText: '08:00',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (previewDurMs != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.waveform.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.waveform.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: AppColors.waveform),
                    const SizedBox(width: 6),
                    Text(
                      'Output Clip Duration: ${TimeParser.formatStandard(previewDurMs)} (${(previewDurMs / 1000).toStringAsFixed(1)}s)',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.waveform),
                    ),
                  ],
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 11, color: AppColors.errorRed)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange, foregroundColor: Colors.white),
          onPressed: _apply,
          child: const Text('Apply Range'),
        ),
      ],
    );
  }
}
