import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/project.dart';
import '../../../providers/project_provider.dart';
import '../../../services/ffmpeg_service.dart';
import '../models/export_config.dart';
import 'export_progress_card.dart';

class ExportDialog extends ConsumerStatefulWidget {
  const ExportDialog({super.key});

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  late VideoResolution _resolution;
  late int _fps;
  final FFmpegService _ffmpegService = FFmpegService();

  bool _isExporting = false;
  bool _isCompleted = false;
  double _progress = 0.0;
  String _statusText = 'Preparing export...';
  String? _finalOutputPath;

  @override
  void initState() {
    super.initState();
    final project = ref.read(projectProvider);
    _resolution = project.resolution;
    _fps = project.fps;
  }

  Future<void> _startExport() async {
    final project = ref.read(projectProvider);
    if (project.images.isEmpty) return;

    final defaultName = '${project.name.toLowerCase().replaceAll(' ', '_')}.mp4';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Video As',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: ['mp4'],
    );

    if (savePath == null) return;
    final validPath = savePath.endsWith('.mp4') ? savePath : '$savePath.mp4';

    final config = ExportConfig(
      resolution: _resolution,
      aspectRatio: project.aspectRatio,
      fps: _fps,
      outputPath: validPath,
    );

    setState(() {
      _isExporting = true;
      _finalOutputPath = validPath;
    });

    try {
      final success = await _ffmpegService.renderVideo(
        project: project,
        config: config,
        onProgress: (pct, msg) {
          if (mounted) setState(() { _progress = pct; _statusText = msg; });
        },
      );

      if (mounted && success) {
        setState(() { _isCompleted = true; _progress = 1.0; _statusText = 'Video saved!'; });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isExporting = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(20),
        child: _isExporting
            ? ExportProgressCard(
                progress: _progress,
                statusText: _statusText,
                isCompleted: _isCompleted,
                outputPath: _finalOutputPath,
                onCancel: () { _ffmpegService.cancel(); Navigator.of(context).pop(); },
                onClose: () => Navigator.of(context).pop(),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.movie_creation, color: AppColors.exportGreen),
                      const SizedBox(width: 8),
                      const Text(
                        'Export Video Settings',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Resolution selector
                  const Text('Resolution', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: VideoResolution.values.map((res) {
                      final isSelected = (_resolution == res);
                      return ChoiceChip(
                        label: Text(res.label, style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        selectedColor: AppColors.clipBlue,
                        backgroundColor: AppColors.background,
                        onSelected: (_) => setState(() => _resolution = res),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Framerate selector
                  const Text('Frame Rate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [24, 30, 60].map((rate) {
                      final isSelected = (_fps == rate);
                      return ChoiceChip(
                        label: Text('$rate FPS', style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        selectedColor: AppColors.clipBlue,
                        backgroundColor: AppColors.background,
                        onSelected: (_) => setState(() => _fps = rate),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Aspect Ratio summary
                  Text(
                    'Aspect Ratio: ${project.aspectRatio.label} (${project.images.length} images)',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.exportGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: _startExport,
                        icon: const Icon(Icons.file_upload_outlined, size: 16),
                        label: const Text('Render Video', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
