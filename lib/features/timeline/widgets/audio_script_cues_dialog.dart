import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/audio_clip_item.dart';
import '../../../providers/project_provider.dart';
import '../../../services/offline_timestamp_service.dart';

/// Dialog for pasting a script for an audio clip so spoken words can be
/// aligned and displayed directly above the audio waveform on the timeline.
class AudioScriptCuesDialog extends ConsumerStatefulWidget {
  final AudioClipItem clip;

  const AudioScriptCuesDialog({super.key, required this.clip});

  @override
  ConsumerState<AudioScriptCuesDialog> createState() => _AudioScriptCuesDialogState();
}

class _AudioScriptCuesDialogState extends ConsumerState<AudioScriptCuesDialog> {
  late final TextEditingController _scriptCtrl;
  bool _highAccuracy = false;
  bool _isGenerating = false;
  String _status = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    final cached = ref.read(audioTranscriptCacheProvider)[widget.clip.filePath.toLowerCase()];
    final initialScript = widget.clip.transcriptScript ?? cached?.scriptText ?? '';
    _scriptCtrl = TextEditingController(text: initialScript);
  }

  @override
  void dispose() {
    _scriptCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final script = _scriptCtrl.text.trim();
    if (script.isEmpty) {
      setState(() => _error = 'Please paste the script for this audio.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
      _status = 'Aligning script words with audio...';
    });

    try {
      final result = await OfflineTimestampService.generateTimestampsAndWords(
        audioPath: widget.clip.filePath,
        scriptText: script,
        granularity: TimestampGranularity.word,
        highAccuracy: _highAccuracy,
        onStatus: (s) {
          if (mounted) setState(() => _status = s);
        },
      );

      if (!mounted) return;
      final cache = Map<String, ({String scriptText, List<AudioWordCue> wordCues})>.from(
        ref.read(audioTranscriptCacheProvider),
      );
      cache[widget.clip.filePath.toLowerCase()] = (
        scriptText: script,
        wordCues: result.wordCues,
      );
      ref.read(audioTranscriptCacheProvider.notifier).state = cache;
      ref.read(projectProvider.notifier).attachWordCuesForAudioPath(
            widget.clip.filePath,
            scriptText: script,
            wordCues: result.wordCues,
          );
      ref.read(showAudioWordCuesProvider.notifier).state = true;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: const Row(
        children: [
          Icon(Icons.subtitles_outlined, size: 18, color: AppColors.waveform),
          SizedBox(width: 8),
          Text(
            'Show Spoken Words Above Audio',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
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
            const SizedBox(height: 6),
            const Text(
              'Paste the script for this audio. Words will be aligned offline and shown right above the waveform so you have a visual cue as you edit or zoom out.',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _scriptCtrl,
              maxLines: 8,
              minLines: 5,
              enabled: !_isGenerating,
              onChanged: (_) => setState(() => _error = null),
              style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.4),
              decoration: InputDecoration(
                hintText: 'Paste spoken script here...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Alignment Mode:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Fast', style: TextStyle(fontSize: 11)),
                  selected: !_highAccuracy,
                  onSelected: _isGenerating ? null : (_) => setState(() => _highAccuracy = false),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('High Accuracy', style: TextStyle(fontSize: 11)),
                  selected: _highAccuracy,
                  onSelected: _isGenerating ? null : (_) => setState(() => _highAccuracy = true),
                ),
              ],
            ),
            if (_isGenerating) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.waveform),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_status, style: const TextStyle(fontSize: 11, color: AppColors.waveform)),
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 11, color: AppColors.errorRed)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.waveform,
            foregroundColor: Colors.black,
          ),
          onPressed: _isGenerating ? null : _generate,
          icon: const Icon(Icons.auto_awesome, size: 15),
          label: const Text('Align & Show Words', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
