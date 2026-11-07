import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/project_provider.dart';
import '../services/csv_service.dart';

class BulkTimestampDialog extends ConsumerStatefulWidget {
  const BulkTimestampDialog({super.key});

  @override
  ConsumerState<BulkTimestampDialog> createState() => _BulkTimestampDialogState();
}

class _BulkTimestampDialogState extends ConsumerState<BulkTimestampDialog> {
  final TextEditingController _textController = TextEditingController();
  List<String> _parsedList = [];

  void _onTextChanged(String text) {
    setState(() {
      _parsedList = CsvService.parseTimestampsFromText(text);
    });
  }

  Future<void> _importCsvFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      _textController.text = content;
      _onTextChanged(content);
    }
  }

  Future<void> _exportCsvFile() async {
    final images = ref.read(projectProvider).images;
    final csvData = CsvService.exportToCsv(images);

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Timestamps CSV',
      fileName: 'project_timestamps.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (savePath != null) {
      final file = File(savePath.endsWith('.csv') ? savePath : '$savePath.csv');
      await file.writeAsString(csvData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported to ${file.path}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageCount = ref.watch(projectProvider.select((p) => p.images.length));
    final matchCount = _parsedList.length;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Actions
            Row(
              children: [
                const Icon(Icons.playlist_add_check, color: AppColors.clipBlue),
                const SizedBox(width: 8),
                const Text(
                  'Bulk Timestamps & CSV',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _importCsvFile,
                  icon: const Icon(Icons.file_open, size: 14),
                  label: const Text('Import CSV', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: _exportCsvFile,
                  icon: const Icon(Icons.download, size: 14),
                  label: const Text('Export CSV', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () {
                    final demoList = List.generate(imageCount > 0 ? imageCount : 26, (i) {
                      final totalSec = (i + 1) * 5 + (i % 3);
                      final m = (totalSec ~/ 60).toString().padLeft(2, '0');
                      final s = (totalSec % 60).toString().padLeft(2, '0');
                      return '$m:$s';
                    });
                    final text = demoList.join('\n');
                    _textController.text = text;
                    _onTextChanged(text);
                  },
                  icon: const Icon(Icons.auto_awesome, size: 14, color: AppColors.accentOrange),
                  label: const Text('Fill Demo', style: TextStyle(fontSize: 11, color: AppColors.accentOrange)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Paste a list of end timestamps (one per line, e.g. 00:05, 00:09.5, 00:15) or CSV data:',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),

            // Input TextField
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: TextField(
                controller: _textController,
                onChanged: _onTextChanged,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: "00:05\n00:09\n00:14\n00:22\n00:31",
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  contentPadding: EdgeInsets.all(12),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Summary Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: matchCount == imageCount ? AppColors.exportGreen.withValues(alpha: 0.15) : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    matchCount == imageCount ? Icons.check_circle : Icons.info_outline,
                    size: 14,
                    color: matchCount == imageCount ? AppColors.exportGreen : AppColors.accentOrange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$matchCount valid timestamps detected for $imageCount images.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: matchCount == imageCount ? AppColors.exportGreen : AppColors.accentOrange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.clipBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: _parsedList.isEmpty
                      ? null
                      : () {
                          ref.read(projectProvider.notifier).applyBulkTimestamps(_parsedList);
                          Navigator.of(context).pop();
                        },
                  child: const Text('Apply to Sequence', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
