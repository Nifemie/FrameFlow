import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/natural_sort.dart';
import 'folder_image_tile.dart';
import 'import_timestamp_dialog.dart';

class FolderImportDialog extends StatefulWidget {
  final String directoryPath;
  final void Function(List<String> paths, List<String> timestamps) onImportConfirmed;

  const FolderImportDialog({
    super.key,
    required this.directoryPath,
    required this.onImportConfirmed,
  });

  @override
  State<FolderImportDialog> createState() => _FolderImportDialogState();
}

class _FolderImportDialogState extends State<FolderImportDialog> {
  bool _includeSubfolders = false;
  bool _isScanning = true;
  List<String> _foundImagePaths = [];
  List<String> _appliedTimestamps = [];

  @override
  void initState() {
    super.initState();
    _scanDirectory();
  }

  Future<void> _scanDirectory() async {
    setState(() => _isScanning = true);
    final dir = Directory(widget.directoryPath);
    if (!await dir.exists()) {
      if (mounted) setState(() { _isScanning = false; _foundImagePaths = []; });
      return;
    }

    final matched = <String>[];
    try {
      await for (final entity in dir.list(recursive: _includeSubfolders, followLinks: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase().replaceAll('.', '');
          if (AppConstants.supportedImageExtensions.contains(ext)) {
            matched.add(entity.path);
          }
        }
      }
      matched.sort((a, b) => NaturalSort.compare(p.basename(a), p.basename(b)));
    } catch (_) {}

    if (mounted) {
      setState(() {
        _foundImagePaths = matched;
        _isScanning = false;
      });
    }
  }

  void _move(int from, int to) {
    if (to < 0 || to >= _foundImagePaths.length) return;
    setState(() {
      final item = _foundImagePaths.removeAt(from);
      _foundImagePaths.insert(to, item);
    });
  }

  Future<void> _openTimestamps() async {
    final res = await showDialog<List<String>>(
      context: context,
      builder: (_) => ImportTimestampDialog(
        imageCount: _foundImagePaths.length,
        initialTimestamps: _appliedTimestamps,
      ),
    );
    if (res != null && mounted) setState(() => _appliedTimestamps = res);
  }

  @override
  Widget build(BuildContext context) {
    final folderName = p.basename(widget.directoryPath);

    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Row(
        children: [
          const Icon(Icons.folder_special, color: AppColors.clipBlueLight, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Import Folder: $folderName',
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 580,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _includeSubfolders, activeColor: AppColors.clipBlue,
                  onChanged: (val) {
                    setState(() => _includeSubfolders = val ?? false);
                    _scanDirectory();
                  },
                ),
                const Text('Include subfolders', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const Spacer(),
                if (!_isScanning)
                  Text('${_foundImagePaths.length} images found',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.exportGreen),
                  ),
              ],
            ),
            const Divider(height: 1, color: AppColors.surfaceBorder),
            const SizedBox(height: 6),
            Expanded(
              child: _isScanning
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.clipBlue))
                  : _foundImagePaths.isEmpty
                      ? const Center(child: Text('No supported images found.', style: TextStyle(color: AppColors.textMuted)))
                      : GridView.builder(
                          itemCount: _foundImagePaths.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 1,
                          ),
                          itemBuilder: (ctx, i) => FolderImageTile(
                            index: i,
                            path: _foundImagePaths[i],
                            timestamp: i < _appliedTimestamps.length ? _appliedTimestamps[i] : null,
                            isLast: i == _foundImagePaths.length - 1,
                            onMove: _move,
                          ),
                        ),
            ),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: _appliedTimestamps.isNotEmpty ? AppColors.exportGreen : AppColors.waveform,
                side: BorderSide(color: _appliedTimestamps.isNotEmpty ? AppColors.exportGreen : AppColors.waveform),
              ),
              icon: const Icon(Icons.timer_outlined, size: 14),
              label: Text(_appliedTimestamps.isEmpty ? 'Set Timestamps' : 'Timestamps (${_appliedTimestamps.length})'),
              onPressed: (_isScanning || _foundImagePaths.isEmpty) ? null : _openTimestamps,
            ),
            const Spacer(),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.clipBlue, foregroundColor: Colors.white),
              onPressed: (_isScanning || _foundImagePaths.isEmpty)
                  ? null
                  : () {
                      widget.onImportConfirmed(_foundImagePaths, _appliedTimestamps);
                      Navigator.of(context).pop();
                    },
              icon: const Icon(Icons.check, size: 16),
              label: Text('Import ${_foundImagePaths.length} Images'),
            ),
          ],
        ),
      ],
    );
  }
}
