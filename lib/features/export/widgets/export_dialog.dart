import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';
import '../../../models/project.dart';
import '../../../providers/export_range_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../services/ffmpeg_service.dart';
import '../models/export_config.dart';
import 'export_progress_card.dart';

enum ExportScope { entire, selectedRange, multipleRanges }

class _EditableRangeEntry {
  final TextEditingController startCtrl;
  final TextEditingController endCtrl;

  _EditableRangeEntry(int startMs, int endMs)
      : startCtrl = TextEditingController(text: TimeParser.formatStandard(startMs)),
        endCtrl = TextEditingController(text: TimeParser.formatStandard(endMs));

  void dispose() {
    startCtrl.dispose();
    endCtrl.dispose();
  }
}

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

  late ExportScope _scope;
  late TextEditingController _startCtrl;
  late TextEditingController _endCtrl;
  final List<_EditableRangeEntry> _multiEntries = [];
  String? _rangeError;

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
    final rangeState = ref.read(exportRangeProvider);
    _resolution = project.resolution;
    _fps = project.fps;

    if (rangeState.savedRanges.isNotEmpty) {
      _scope = ExportScope.multipleRanges;
    } else if (rangeState.hasRange) {
      _scope = ExportScope.selectedRange;
    } else {
      _scope = ExportScope.entire;
    }

    final initialStart = rangeState.inMs ?? 0;
    final initialEnd = rangeState.outMs ?? (project.totalDurationMs > 0 ? project.totalDurationMs : 5000);
    _startCtrl = TextEditingController(text: TimeParser.formatStandard(initialStart));
    _endCtrl = TextEditingController(text: TimeParser.formatStandard(initialEnd));

    for (final r in rangeState.savedRanges) {
      _multiEntries.add(_EditableRangeEntry(r.startMs, r.endMs));
    }
    if (_multiEntries.isEmpty && rangeState.hasRange) {
      _multiEntries.add(_EditableRangeEntry(rangeState.inMs!, rangeState.outMs!));
    }
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    for (final e in _multiEntries) {
      e.dispose();
    }
    super.dispose();
  }

  ({int startMs, int endMs})? _parsePair(String startText, String endText, int totalDurationMs, {String prefix = ''}) {
    final s = TimeParser.parseToMs(startText.trim());
    var e = TimeParser.parseToMs(endText.trim());
    if (s == null || e == null) {
      setState(() => _rangeError = '${prefix}Enter valid timecodes (e.g. 00:05.00)');
      return null;
    }
    if (e > totalDurationMs && e - totalDurationMs <= 20) {
      e = totalDurationMs;
    }
    if (s < 0 || e > totalDurationMs) {
      setState(() => _rangeError = '${prefix}Range must stay within 00:00.00 – ${TimeParser.formatStandard(totalDurationMs)}');
      return null;
    }
    if (e <= s) {
      setState(() => _rangeError = '${prefix}End time must be greater than start time');
      return null;
    }
    return (startMs: s, endMs: e);
  }

  void _syncMultiEntriesToProvider(int totalDurationMs) {
    final notifier = ref.read(exportRangeProvider.notifier);
    notifier.clearSavedRanges();
    for (final entry in _multiEntries) {
      final s = TimeParser.parseToMs(entry.startCtrl.text.trim());
      var e = TimeParser.parseToMs(entry.endCtrl.text.trim());
      if (s != null && e != null) {
        if (e > totalDurationMs && e - totalDurationMs <= 20) e = totalDurationMs;
        if (s >= 0 && e > s && e <= totalDurationMs) {
          notifier.addRange(ExportRange(startMs: s, endMs: e));
        }
      }
    }
  }

  void _addEditableMultiRange(int totalDurationMs) {
    final defaultEnd = totalDurationMs > 0 ? totalDurationMs.clamp(0, 5000) : 5000;
    setState(() {
      _multiEntries.add(_EditableRangeEntry(0, defaultEnd));
      _rangeError = null;
    });
    _syncMultiEntriesToProvider(totalDurationMs);
  }

  void _removeEditableMultiRange(int idx, int totalDurationMs) {
    setState(() {
      _multiEntries[idx].dispose();
      _multiEntries.removeAt(idx);
      _rangeError = null;
    });
    _syncMultiEntriesToProvider(totalDurationMs);
  }

  Future<void> _startExport() async {
    final project = ref.read(projectProvider);
    if (project.images.isEmpty) return;

    List<ExportRange> rangesToExport = [];
    if (_scope == ExportScope.selectedRange) {
      final parsed = _parsePair(_startCtrl.text, _endCtrl.text, project.totalDurationMs);
      if (parsed == null) return;
      setState(() => _rangeError = null);
      ref.read(exportRangeProvider.notifier).setRange(parsed.startMs, parsed.endMs);
      rangesToExport = [ExportRange(startMs: parsed.startMs, endMs: parsed.endMs)];
    } else if (_scope == ExportScope.multipleRanges) {
      if (_multiEntries.isEmpty) {
        setState(() => _rangeError = 'Click "+ Add Range" to add at least one range.');
        return;
      }
      for (int i = 0; i < _multiEntries.length; i++) {
        final parsed = _parsePair(
          _multiEntries[i].startCtrl.text,
          _multiEntries[i].endCtrl.text,
          project.totalDurationMs,
          prefix: 'Range #${i + 1}: ',
        );
        if (parsed == null) return;
        rangesToExport.add(ExportRange(startMs: parsed.startMs, endMs: parsed.endMs));
      }
      setState(() => _rangeError = null);
      _syncMultiEntriesToProvider(project.totalDurationMs);
    }

    final ext = _format.extension.replaceAll('.', '');
    final defaultName = '${project.name.toLowerCase().replaceAll(' ', '_')}.$ext';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: _scope == ExportScope.multipleRanges ? 'Choose Base Filename for Ranges' : 'Export Video As',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: [ext],
    );
    if (savePath == null) return;
    final validPath = savePath.endsWith('.$ext') ? savePath : '$savePath.$ext';

    setState(() {
      _isExporting = true;
      _finalOutputPath = validPath;
      _rangeError = null;
    });

    try {
      if (_scope == ExportScope.entire) {
        final config = ExportConfig(
          resolution: _resolution,
          aspectRatio: project.aspectRatio,
          fps: _fps,
          format: _format,
          codec: _codec,
          quality: _quality,
          outputPath: validPath,
        );
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
      } else {
        final totalCount = rangesToExport.length;
        final baseNoExt = validPath.substring(0, validPath.length - ext.length - 1);
        for (int idx = 0; idx < totalCount; idx++) {
          final r = rangesToExport[idx];
          final outPath = totalCount == 1 ? validPath : '${baseNoExt}_range${idx + 1}.$ext';
          final config = ExportConfig(
            resolution: _resolution,
            aspectRatio: project.aspectRatio,
            fps: _fps,
            format: _format,
            codec: _codec,
            quality: _quality,
            outputPath: outPath,
          );
          final success = await _ffmpegService.renderVideo(
            project: project,
            config: config,
            rangeStartMs: r.startMs,
            rangeEndMs: r.endMs,
            onProgress: (pct, msg) {
              if (mounted) {
                final combined = (idx + pct) / totalCount;
                setState(() {
                  _progress = combined;
                  _statusText = totalCount > 1 ? '[Range ${idx + 1}/$totalCount] $msg' : msg;
                });
              }
            },
          );
          if (!success) return;
          _finalOutputPath = outPath;
        }
        if (mounted) {
          setState(() {
            _isCompleted = true;
            _progress = 1.0;
            _statusText = totalCount > 1 ? 'Exported $totalCount ranges!' : 'Selected range saved!';
          });
        }
      }
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

    final parsedStart = TimeParser.parseToMs(_startCtrl.text.trim()) ?? 0;
    final parsedEnd = TimeParser.parseToMs(_endCtrl.text.trim()) ?? 0;
    final rangeDurationMs = (parsedEnd - parsedStart).clamp(0, project.totalDurationMs);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(18),
        child: _isExporting
            ? ExportProgressCard(
                progress: _progress,
                statusText: _statusText,
                isCompleted: _isCompleted,
                outputPath: _finalOutputPath,
                onCancel: () {
                  _ffmpegService.cancel();
                  Navigator.of(context).pop();
                },
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

                    // Export Scope Selector
                    const Text('Export Scope', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _scopeChip(ExportScope.entire, 'Entire Timeline'),
                        const SizedBox(width: 6),
                        _scopeChip(ExportScope.selectedRange, 'Selected Range'),
                        const SizedBox(width: 6),
                        _scopeChip(ExportScope.multipleRanges, 'Multiple Ranges (${_multiEntries.length})'),
                      ],
                    ),

                    if (_scope == ExportScope.selectedRange) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.exportGreen.withValues(alpha: 0.45)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _startCtrl,
                                    style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: Colors.white),
                                    decoration: const InputDecoration(labelText: 'In (Start)', isDense: true),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _endCtrl,
                                    style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: Colors.white),
                                    decoration: const InputDecoration(labelText: 'Out (End)', isDense: true),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Duration', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                    Text(
                                      TimeParser.formatStandard(rangeDurationMs),
                                      style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.exportGreen),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (_rangeError != null) ...[
                              const SizedBox(height: 6),
                              Text(_rangeError!, style: const TextStyle(fontSize: 11, color: AppColors.errorRed)),
                            ],
                          ],
                        ),
                      ),
                    ],

                    if (_scope == ExportScope.multipleRanges) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.exportGreen.withValues(alpha: 0.45)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Custom Export Ranges (${_multiEntries.length})',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _addEditableMultiRange(project.totalDurationMs),
                                  icon: const Icon(Icons.add, size: 13),
                                  label: const Text('Add Range', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.exportGreen.withValues(alpha: 0.2),
                                    foregroundColor: AppColors.exportGreen,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_multiEntries.isEmpty)
                              const Text('No ranges yet. Click "+ Add Range" to create an editable range.', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted))
                            else
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 190),
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      for (int i = 0; i < _multiEntries.length; i++)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceLight,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text('#${i + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.exportGreen)),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TextField(
                                                  controller: _multiEntries[i].startCtrl,
                                                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: Colors.white),
                                                  decoration: const InputDecoration(labelText: 'In (Start)', isDense: true),
                                                  onChanged: (_) {
                                                    setState(() {});
                                                    _syncMultiEntriesToProvider(project.totalDurationMs);
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TextField(
                                                  controller: _multiEntries[i].endCtrl,
                                                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: Colors.white),
                                                  decoration: const InputDecoration(labelText: 'Out (End)', isDense: true),
                                                  onChanged: (_) {
                                                    setState(() {});
                                                    _syncMultiEntriesToProvider(project.totalDurationMs);
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Builder(builder: (_) {
                                                final s = TimeParser.parseToMs(_multiEntries[i].startCtrl.text.trim()) ?? 0;
                                                final e = TimeParser.parseToMs(_multiEntries[i].endCtrl.text.trim()) ?? 0;
                                                final d = (e - s).clamp(0, project.totalDurationMs);
                                                return Text(
                                                  TimeParser.formatStandard(d),
                                                  style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.exportGreen),
                                                );
                                              }),
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(Icons.close, size: 15, color: Colors.white70),
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                                tooltip: 'Remove Range',
                                                onPressed: () => _removeEditableMultiRange(i, project.totalDurationMs),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            if (_multiEntries.isNotEmpty)
                              Text(
                                '${_multiEntries.length} range(s) will export one after another (_range1, _range2, ...).',
                                style: const TextStyle(fontSize: 10, color: AppColors.exportGreen),
                              ),
                            if (_rangeError != null) ...[
                              const SizedBox(height: 6),
                              Text(_rangeError!, style: const TextStyle(fontSize: 11, color: AppColors.errorRed)),
                            ],
                          ],
                        ),
                      ),
                    ],

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
                      _scope == ExportScope.entire
                          ? 'Aspect Ratio: ${project.aspectRatio.label} • Duration: ${TimeParser.formatStandard(project.totalDurationMs)} (${project.images.length} clips)'
                          : 'Aspect Ratio: ${project.aspectRatio.label} • Selective Range Export',
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
                          label: Text(_scope == ExportScope.entire ? 'Render Video' : 'Render Selected Range', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _scopeChip(ExportScope scope, String label) {
    final active = _scope == scope;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() {
          _scope = scope;
          _rangeError = null;
          if (scope == ExportScope.multipleRanges && _multiEntries.isEmpty) {
            final project = ref.read(projectProvider);
            final defaultEnd = project.totalDurationMs > 0 ? project.totalDurationMs.clamp(0, 5000) : 5000;
            _multiEntries.add(_EditableRangeEntry(0, defaultEnd));
          }
        }),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.exportGreen.withValues(alpha: 0.2) : AppColors.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: active ? AppColors.exportGreen : AppColors.surfaceBorder),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: active ? AppColors.exportGreen : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
