import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/project_provider.dart';
import '../services/csv_service.dart';

class BulkTimestampDialog extends ConsumerStatefulWidget {
  final String? trackId;
  final String? trackName;
  final bool isAudio;

  const BulkTimestampDialog({super.key, this.trackId, this.trackName, this.isAudio = false});

  @override
  ConsumerState<BulkTimestampDialog> createState() => _BulkTimestampDialogState();
}

class _BulkTimestampDialogState extends ConsumerState<BulkTimestampDialog> {
  final TextEditingController _textController = TextEditingController();
  List<String> _parsedList = [];

  void _onTextChanged(String text) {
    setState(() => _parsedList = CsvService.parseTimestampsFromText(text));
  }

  Future<void> _importCsvFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt']);
    if (result != null && result.files.single.path != null) {
      final content = await File(result.files.single.path!).readAsString();
      _textController.text = content;
      _onTextChanged(content);
    }
  }

  Future<void> _exportCsvFile() async {
    final String csvData;
    if (widget.isAudio) {
      final clips = ref.read(projectProvider).effectiveAudioClips;
      final buffer = StringBuffer()..writeln('Index,File Name,Start Time,End Time,Duration (s)');
      for (int i = 0; i < clips.length; i++) {
        final c = clips[i];
        buffer.writeln('${i + 1},"${c.fileName}",${c.startTimelineMs / 1000.0},${c.endTimelineMs / 1000.0},${(c.durationMs / 1000.0).toStringAsFixed(2)}');
      }
      csvData = buffer.toString();
    } else {
      final images = widget.trackId != null
          ? ref.read(projectProvider).imagesForTrack(widget.trackId!)
          : ref.read(projectProvider).images;
      csvData = CsvService.exportToCsv(images);
    }
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Timestamps CSV',
      fileName: widget.isAudio ? 'audio_timestamps.csv' : 'project_timestamps.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (savePath != null) {
      final file = File(savePath.endsWith('.csv') ? savePath : '$savePath.csv');
      await file.writeAsString(csvData);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported: ${file.path}')));
    }
  }

  void _fillDemo(int count) {
    final demoList = List.generate(count > 0 ? count : (widget.isAudio ? 5 : 20), (i) {
      final sec = (i + 1) * (widget.isAudio ? 15 : 5);
      return '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';
    });
    final text = demoList.join('\n');
    _textController.text = text;
    _onTextChanged(text);
  }

  @override
  Widget build(BuildContext context) {
    final int targetCount;
    if (widget.isAudio) {
      targetCount = ref.watch(projectProvider.select((p) => p.effectiveAudioClips.length));
    } else {
      final targetImages = widget.trackId != null
          ? ref.watch(projectProvider.select((p) => p.imagesForTrack(widget.trackId!)))
          : ref.watch(projectProvider.select((p) => p.images));
      targetCount = targetImages.length;
    }
    final matchCount = _parsedList.length;
    final title = widget.trackName != null
        ? 'Align Timestamps: ${widget.trackName}'
        : (widget.isAudio ? 'Audio Timestamps & Start Offsets' : 'Bulk Timestamps & CSV');
    final itemTypeLabel = widget.isAudio ? 'soundtracks / clips' : 'images';

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 530,
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(
                widget.isAudio ? Icons.audiotrack : Icons.playlist_add_check,
                color: widget.isAudio ? AppColors.accentOrange : AppColors.clipBlue,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
              TextButton.icon(onPressed: _importCsvFile, icon: const Icon(Icons.file_open, size: 14), label: const Text('Import', style: TextStyle(fontSize: 11))),
              TextButton.icon(onPressed: _exportCsvFile, icon: const Icon(Icons.download, size: 14), label: const Text('Export', style: TextStyle(fontSize: 11))),
              TextButton.icon(
                onPressed: () => _fillDemo(targetCount),
                icon: const Icon(Icons.auto_awesome, size: 14, color: AppColors.accentOrange),
                label: const Text('Fill Demo', style: TextStyle(fontSize: 11, color: AppColors.accentOrange)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(
              widget.isAudio
                  ? 'Paste start timestamps for each soundtrack/clip (e.g. 00:00, 00:15, 01:20):'
                  : 'Paste timestamps or ranges for blank gaps (e.g. 00:04, 00:10 - 00:15):',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),

            Container(
              height: 160,
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.surfaceBorder)),
              child: TextField(
                controller: _textController,
                onChanged: _onTextChanged,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: widget.isAudio
                      ? "00:00 (Intro soundtrack)\n00:15 (Background beat)\n01:10 (Outro music)"
                      : "00:03\n00:04\n00:10 - 00:15 (blank gap before)\n00:19",
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  contentPadding: const EdgeInsets.all(10),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: matchCount == targetCount && targetCount > 0 ? AppColors.exportGreen.withValues(alpha: 0.15) : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(children: [
                Icon(matchCount == targetCount && targetCount > 0 ? Icons.check_circle : Icons.info_outline, size: 14, color: matchCount == targetCount && targetCount > 0 ? AppColors.exportGreen : AppColors.accentOrange),
                const SizedBox(width: 6),
                Text('$matchCount valid timestamps detected for $targetCount $itemTypeLabel on this track.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: matchCount == targetCount && targetCount > 0 ? AppColors.exportGreen : AppColors.accentOrange)),
              ]),
            ),
            const SizedBox(height: 14),

            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted))),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isAudio ? AppColors.accentOrange : AppColors.clipBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _parsedList.isEmpty ? null : () {
                  if (widget.isAudio) {
                    ref.read(projectProvider.notifier).applyAudioBulkTimestamps(_parsedList);
                  } else {
                    ref.read(projectProvider.notifier).applyBulkTimestamps(_parsedList, trackId: widget.trackId);
                  }
                  Navigator.of(context).pop();
                },
                child: const Text('Apply to Sequence', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
