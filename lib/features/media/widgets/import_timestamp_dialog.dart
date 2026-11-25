import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../timestamps/services/csv_service.dart';

class ImportTimestampDialog extends StatefulWidget {
  final int imageCount;
  final List<String> initialTimestamps;

  const ImportTimestampDialog({
    super.key,
    required this.imageCount,
    required this.initialTimestamps,
  });

  @override
  State<ImportTimestampDialog> createState() => _ImportTimestampDialogState();
}

class _ImportTimestampDialogState extends State<ImportTimestampDialog> {
  late final TextEditingController _controller;
  List<String> _parsed = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTimestamps.join('\n'));
    _parsed = List.from(widget.initialTimestamps);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String val) {
    setState(() => _parsed = CsvService.parseTimestampsFromText(val));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Row(
        children: [
          const Icon(Icons.timer, color: AppColors.waveform, size: 20),
          const SizedBox(width: 8),
          const Text('Paste Folder Timestamps', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${_parsed.length}/${widget.imageCount} set', style: const TextStyle(fontSize: 11, color: AppColors.exportGreen)),
        ],
      ),
      content: SizedBox(
        width: 360,
        height: 260,
        child: Column(
          children: [
            const Text('Paste timestamps or ranges for blank gaps (e.g. 00:04, 00:10 - 00:15):', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white),
                decoration: InputDecoration(
                  hintText: '00:03\n00:04\n00:10 - 00:15 (blank gap before)\n00:19...',
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                ),
                onChanged: _onChanged,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        if (_parsed.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(<String>[]),
            child: const Text('Clear', style: TextStyle(color: AppColors.errorRed)),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.clipBlue, foregroundColor: Colors.white),
          onPressed: () => Navigator.of(context).pop(_parsed),
          child: Text('Apply ${_parsed.length} Timestamps'),
        ),
      ],
    );
  }
}
