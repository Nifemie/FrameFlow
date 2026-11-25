import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';
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
  ExportFormat _format = ExportFormat.mp4;
  VideoCodec _codec = VideoCodec.h264;
  QualityPreset _quality = QualityPreset.high;

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

    final ext = _format.extension.replaceAll('.', '');
    final defaultName = '${project.name.toLowerCase().replaceAll(' ', '_')}.$ext';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Video As', fileName: defaultName, type: FileType.custom, allowedExtensions: [ext],
    );
    if (savePath == null) return;
    final validPath = savePath.endsWith('.$ext') ? savePath : '$savePath.$ext';

    final config = ExportConfig(
      resolution: _resolution, aspectRatio: project.aspectRatio, fps: _fps,
      format: _format, codec: _codec, quality: _quality, outputPath: validPath,
    );

    setState(() { _isExporting = true; _finalOutputPath = validPath; });

    try {
      final success = await _ffmpegService.renderVideo(
        project: project, config: config,
        onProgress: (pct, msg) { if (mounted) setState(() { _progress = pct; _statusText = msg; }); },
      );
      if (mounted && success) setState(() { _isCompleted = true; _progress = 1.0; _statusText = 'Video saved!'; });
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
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
        width: 500,
        padding: const EdgeInsets.all(18),
        child: _isExporting
            ? ExportProgressCard(
                progress: _progress, statusText: _statusText, isCompleted: _isCompleted,
                outputPath: _finalOutputPath, onCancel: () { _ffmpegService.cancel(); Navigator.of(context).pop(); },
                onClose: () => Navigator.of(context).pop(),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.movie_creation, color: AppColors.exportGreen, size: 20),
                      SizedBox(width: 8),
                      Text('Export Video Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<ExportFormat>(
                          initialValue: _format,
                          decoration: const InputDecoration(labelText: 'Format', isDense: true),
                          items: ExportFormat.values.map((f) => DropdownMenuItem(value: f, child: Text(f.label, style: const TextStyle(fontSize: 11)))).toList(),
                          onChanged: (val) { if (val != null) setState(() => _format = val); },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<VideoCodec>(
                          initialValue: _codec,
                          decoration: const InputDecoration(labelText: 'Codec', isDense: true),
                          items: VideoCodec.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label, style: const TextStyle(fontSize: 11)))).toList(),
                          onChanged: (val) { if (val != null) setState(() => _codec = val); },
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<QualityPreset>(
                          initialValue: _quality,
                          decoration: const InputDecoration(labelText: 'Quality', isDense: true),
                          items: QualityPreset.values.map((q) => DropdownMenuItem(value: q, child: Text(q.label, style: const TextStyle(fontSize: 11)))).toList(),
                          onChanged: (val) { if (val != null) setState(() => _quality = val); },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _fps,
                          decoration: const InputDecoration(labelText: 'Frame Rate', isDense: true),
                          items: [24, 25, 30, 50, 60].map((rate) => DropdownMenuItem(value: rate, child: Text('$rate FPS', style: const TextStyle(fontSize: 11)))).toList(),
                          onChanged: (val) { if (val != null) setState(() => _fps = val); },
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    const Text('Resolution', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: VideoResolution.values.map((res) => ChoiceChip(
                        label: Text(res.label, style: const TextStyle(fontSize: 10)),
                        selected: _resolution == res,
                        selectedColor: AppColors.clipBlue,
                        backgroundColor: AppColors.background,
                        onSelected: (_) => setState(() => _resolution = res),
                      )).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aspect Ratio: ${project.aspectRatio.label} • Duration: ${TimeParser.formatStandard(project.totalDurationMs)} (${project.images.length} clips)',
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.exportGreen, foregroundColor: Colors.white),
                          onPressed: _startExport,
                          icon: const Icon(Icons.file_upload_outlined, size: 16),
                          label: const Text('Render Video', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
