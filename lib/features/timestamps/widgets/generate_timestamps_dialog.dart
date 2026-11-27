import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';
import '../../../models/audio_clip_item.dart';
import '../../../models/text_overlay_item.dart';
import '../../../models/timeline_track_item.dart';
import '../../../providers/project_provider.dart';
import '../../../services/offline_timestamp_service.dart';

class GenerateTimestampsDialog extends ConsumerStatefulWidget {
  final bool showLastResults;

  const GenerateTimestampsDialog({super.key, this.showLastResults = false});

  @override
  ConsumerState<GenerateTimestampsDialog> createState() => _GenerateTimestampsDialogState();
}

class _GenerateTimestampsDialogState extends ConsumerState<GenerateTimestampsDialog> {
  bool _useTimelineAudio = true;
  String? _selectedTimelineAudioId;
  String? _uploadedAudioPath;

  final TextEditingController _scriptCtrl = TextEditingController();
  TimestampGranularity _granularity = TimestampGranularity.sentence;
  TimestampFormatMode _formatMode = TimestampFormatMode.both;
  bool _highAccuracy = false;

  bool _isGenerating = false;
  String _status = '';
  String? _error;

  List<GeneratedTimestampRow>? _rows;
  String? _activeAudioPath;
  String? _selectedTargetTrackId;

  final AudioPlayer _slicePlayer = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSub;
  Timer? _sliceTimer;
  String? _openedAudioPath;
  int? _playingRowIndex;

  @override
  void initState() {
    super.initState();
    final project = ref.read(projectProvider);
    final audioClips = project.effectiveAudioClips;
    if (audioClips.isNotEmpty) {
      _selectedTimelineAudioId = audioClips.first.id;
      _useTimelineAudio = true;
    } else {
      _useTimelineAudio = false;
    }
    final tracks = project.effectiveTracks.where((t) => t.isVideoOrBg || t.type == TrackType.text).toList();
    if (tracks.isNotEmpty) {
      _selectedTargetTrackId = tracks.first.id;
    }

    if (widget.showLastResults) {
      final last = ref.read(lastGeneratedTimestampsProvider);
      if (last != null && last.rows.isNotEmpty) {
        _rows = last.rows;
        _activeAudioPath = last.audioPath;
        _scriptCtrl.text = last.scriptText;
        _granularity = last.granularity;
        _formatMode = last.formatMode;
      }
    }

    _stateSub = _slicePlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) setState(() => _playingRowIndex = null);
      }
    });
  }

  @override
  void dispose() {
    _sliceTimer?.cancel();
    _stateSub?.cancel();
    _slicePlayer.dispose();
    _scriptCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    final res = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Audio File',
      type: FileType.custom,
      allowedExtensions: AppConstants.supportedAudioExtensions,
    );
    if (res != null && res.files.single.path != null) {
      setState(() {
        _uploadedAudioPath = res.files.single.path!;
        _useTimelineAudio = false;
        _error = null;
      });
    }
  }

  Future<void> _pickScriptFile() async {
    final res = await FilePicker.platform.pickFiles(
      dialogTitle: 'Upload Script (.txt)',
      type: FileType.custom,
      allowedExtensions: ['txt', 'md', 'srt'],
    );
    if (res != null && res.files.single.path != null) {
      final text = await File(res.files.single.path!).readAsString();
      setState(() {
        _scriptCtrl.text = text;
        _error = null;
      });
    }
  }

  String? _resolveAudioPath() {
    if (!_useTimelineAudio) return _uploadedAudioPath;
    final clips = ref.read(projectProvider).effectiveAudioClips;
    final match = clips.where((c) => c.id == _selectedTimelineAudioId).firstOrNull;
    return match?.filePath;
  }

  Future<void> _runGeneration() async {
    final audioPath = _resolveAudioPath();
    if (audioPath == null || audioPath.isEmpty) {
      setState(() => _error = 'Please upload an audio file or select one from the timeline.');
      return;
    }
    final script = _scriptCtrl.text.trim();
    if (script.isEmpty) {
      setState(() => _error = 'Please upload or paste your script.');
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
      _status = 'Starting offline alignment...';
    });

    try {
      final rows = await OfflineTimestampService.generateTimestamps(
        audioPath: audioPath,
        scriptText: script,
        granularity: _granularity,
        highAccuracy: _highAccuracy,
        onStatus: (s) {
          if (mounted) setState(() => _status = s);
        },
      );
      if (mounted) {
        ref.read(lastGeneratedTimestampsProvider.notifier).state = LastGeneratedTimestamps(
          audioPath: audioPath,
          scriptText: script,
          granularity: _granularity,
          formatMode: _formatMode,
          rows: rows,
        );
        setState(() {
          _isGenerating = false;
          _rows = rows;
          _activeAudioPath = audioPath;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _playAudioSlice(GeneratedTimestampRow row) async {
    if (_activeAudioPath == null) return;
    if (_playingRowIndex == row.index) {
      await _stopAudioSlice();
      return;
    }
    _sliceTimer?.cancel();
    try {
      if (_openedAudioPath != null) {
        await _slicePlayer.pause();
      }
      if (_openedAudioPath != _activeAudioPath) {
        await _slicePlayer.setFilePath(_activeAudioPath!);
        _openedAudioPath = _activeAudioPath;
      }
      await _slicePlayer.setVolume(1.0);
      await _slicePlayer.seek(Duration(milliseconds: row.startMs));
      if (!mounted) return;
      setState(() {
        _playingRowIndex = row.index;
      });
      _slicePlayer.play();
      final sliceMs = (row.endMs - row.startMs).clamp(150, 600000);
      _sliceTimer = Timer(Duration(milliseconds: sliceMs), () {
        if (mounted && _playingRowIndex == row.index) {
          _stopAudioSlice();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _playingRowIndex = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio slice playback error: $e')),
        );
      }
    }
  }

  Future<void> _stopAudioSlice() async {
    _sliceTimer?.cancel();
    _sliceTimer = null;
    try {
      if (_openedAudioPath != null) {
        await _slicePlayer.pause();
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _playingRowIndex = null);
    }
  }

  void _copyTimestamps() {
    final rows = _rows;
    if (rows == null || rows.isEmpty) return;
    final text = rows.map((r) => r.formatTimestamp(_formatMode)).join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${rows.length} timestamp(s) to clipboard!')),
    );
  }

  void _applyToTimeline() {
    final rows = _rows;
    final trackId = _selectedTargetTrackId;
    if (rows == null || rows.isEmpty || trackId == null) return;

    final project = ref.read(projectProvider);
    final notifier = ref.read(projectProvider.notifier);
    final track = project.effectiveTracks.where((t) => t.id == trackId).firstOrNull;
    if (track == null) return;

    if (track.type == TrackType.text) {
      for (final r in rows) {
        notifier.addTextOverlay(TextOverlayItem(
          id: '${DateTime.now().microsecondsSinceEpoch}_${r.index}',
          text: r.text,
          startMs: r.startMs,
          durationMs: (r.endMs - r.startMs).clamp(300, 600000),
        ));
      }
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${rows.length} text title(s) to "${track.name}"')),
      );
      return;
    }

    final List<String> lines;
    if (_formatMode == TimestampFormatMode.endingOnly) {
      // Single ending timestamps -> each clip automatically starts where the previous ended (no gaps)
      lines = rows.map((r) => TimeParser.formatStandard(r.endMs)).toList();
    } else if (_formatMode == TimestampFormatMode.beginningOnly) {
      // Continuous start-to-next-start ranges (no gaps)
      lines = [
        for (int i = 0; i < rows.length; i++)
          '${TimeParser.formatStandard(rows[i].startMs)} - ${TimeParser.formatStandard(i + 1 < rows.length ? rows[i + 1].startMs : rows[i].endMs)}',
      ];
    } else {
      lines = rows.map((r) => '${TimeParser.formatStandard(r.startMs)} - ${TimeParser.formatStandard(r.endMs)}').toList();
    }
    notifier.applyBulkTimestamps(lines, trackId: trackId);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Applied timestamps to "${track.name}"')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider);
    final audioClips = project.effectiveAudioClips;
    final targetTracks = project.effectiveTracks.where((t) => t.isVideoOrBg || t.type == TrackType.text).toList();

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        width: _rows != null ? 880 : 540,
        padding: const EdgeInsets.all(20),
        child: _rows == null
            ? _buildSetupView(audioClips)
            : _buildResultsView(targetTracks),
      ),
    );
  }

  Widget _buildSetupView(List<AudioClipItem> audioClips) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.record_voice_over_outlined, color: AppColors.accentOrange, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Generate Offline Timestamps', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          const Text('1. Choose Audio Source', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Pick from Timeline', style: TextStyle(fontSize: 11)),
                  selected: _useTimelineAudio,
                  selectedColor: AppColors.accentOrange.withValues(alpha: 0.25),
                  onSelected: audioClips.isEmpty ? null : (_) => setState(() => _useTimelineAudio = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Upload Audio File', style: TextStyle(fontSize: 11)),
                  selected: !_useTimelineAudio,
                  selectedColor: AppColors.accentOrange.withValues(alpha: 0.25),
                  onSelected: (_) => setState(() => _useTimelineAudio = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_useTimelineAudio && audioClips.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _selectedTimelineAudioId,
              decoration: const InputDecoration(labelText: 'Timeline Audio Clip', isDense: true),
              items: audioClips
                  .map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text('${c.fileName} (${TimeParser.formatStandard(c.durationMs)})', style: const TextStyle(fontSize: 11.5)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _selectedTimelineAudioId = v),
            )
          else
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickAudioFile,
                  icon: const Icon(Icons.audio_file_outlined, size: 15),
                  label: const Text('Browse Audio...', style: TextStyle(fontSize: 11.5)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _uploadedAudioPath != null ? p.basename(_uploadedAudioPath!) : 'No audio selected',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('2. Script (Every Spoken Word)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              TextButton.icon(
                onPressed: _pickScriptFile,
                icon: const Icon(Icons.upload_file, size: 14, color: AppColors.accentOrange),
                label: const Text('Upload .txt', style: TextStyle(fontSize: 11, color: AppColors.accentOrange)),
              ),
            ],
          ),
          TextField(
            controller: _scriptCtrl,
            maxLines: 5,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Paste or upload the exact script spoken in the audio...',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),
          const Text('3. Timestamp Options', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<TimestampGranularity>(
                  initialValue: _granularity,
                  decoration: const InputDecoration(labelText: 'Split By', isDense: true),
                  items: const [
                    DropdownMenuItem(value: TimestampGranularity.sentence, child: Text('Every Sentence', style: TextStyle(fontSize: 11.5))),
                    DropdownMenuItem(value: TimestampGranularity.word, child: Text('Every Word', style: TextStyle(fontSize: 11.5))),
                  ],
                  onChanged: (v) { if (v != null) setState(() => _granularity = v); },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<TimestampFormatMode>(
                  initialValue: _formatMode,
                  decoration: const InputDecoration(labelText: 'Timestamp Type', isDense: true),
                  items: TimestampFormatMode.values
                      .map((m) => DropdownMenuItem(value: m, child: Text(m.label, style: const TextStyle(fontSize: 11.5))))
                      .toList(),
                  onChanged: (v) { if (v != null) setState(() => _formatMode = v); },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Fast', style: TextStyle(fontSize: 11)),
                  selected: !_highAccuracy,
                  selectedColor: AppColors.accentOrange.withValues(alpha: 0.25),
                  onSelected: (_) => setState(() => _highAccuracy = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('High Accuracy', style: TextStyle(fontSize: 11)),
                  selected: _highAccuracy,
                  selectedColor: AppColors.accentOrange.withValues(alpha: 0.25),
                  onSelected: (_) => setState(() => _highAccuracy = true),
                ),
              ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(fontSize: 11.5, color: AppColors.errorRed)),
          ],
          if (_isGenerating) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentOrange)),
                const SizedBox(width: 10),
                Expanded(child: Text(_status, style: const TextStyle(fontSize: 11.5, color: AppColors.accentOrange))),
              ],
            ),
          ],

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: _isGenerating ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentOrange, foregroundColor: Colors.white),
                onPressed: _isGenerating ? null : _runGeneration,
                icon: const Icon(Icons.auto_awesome, size: 15),
                label: const Text('Generate Timestamps', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView(List<TimelineTrackItem> targetTracks) {
    final rows = _rows!;
    final tsColWidth = _formatMode == TimestampFormatMode.both ? 150.0 : 90.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.table_chart_outlined, color: AppColors.accentOrange, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Generated Timestamps (${rows.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                _stopAudioSlice();
                setState(() => _rows = null);
              },
              icon: const Icon(Icons.arrow_back, size: 14),
              label: const Text('Back', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          child: Row(
            children: [
              const SizedBox(width: 32, child: Text('#', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
              SizedBox(width: tsColWidth, child: const Text('Timestamp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
              const SizedBox(width: 10),
              const Expanded(child: Text('Word / Sentence', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
              const SizedBox(width: 10),
              const SizedBox(width: 80, child: Text('Audio', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary))),
            ],
          ),
        ),

        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 460),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              border: const Border(
                left: BorderSide(color: AppColors.surfaceBorder),
                right: BorderSide(color: AppColors.surfaceBorder),
                bottom: BorderSide(color: AppColors.surfaceBorder),
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.surfaceBorderSubtle),
              itemBuilder: (ctx, idx) {
                final r = rows[idx];
                final isPlayingThis = _playingRowIndex == r.index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text('${r.index}', style: const TextStyle(fontFamily: 'Consolas', fontSize: 11.5, color: AppColors.accentOrange, fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(
                        width: tsColWidth,
                        child: TextFormField(
                          initialValue: r.formatTimestamp(_formatMode),
                          style: const TextStyle(fontFamily: 'Consolas', fontSize: 11.5, color: Colors.white),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.surfaceLight,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none),
                          ),
                          onChanged: (val) {
                            final parts = val.split(RegExp(r'\s*[-–→]\s*'));
                            if (_formatMode == TimestampFormatMode.both && parts.length == 2) {
                              final s = TimeParser.parseToMs(parts[0]);
                              final e = TimeParser.parseToMs(parts[1]);
                              if (s != null && e != null && e > s) {
                                r.startMs = s;
                                r.endMs = e;
                              }
                            } else if (_formatMode == TimestampFormatMode.beginningOnly) {
                              final s = TimeParser.parseToMs(val);
                              if (s != null) r.startMs = s;
                            } else if (_formatMode == TimestampFormatMode.endingOnly) {
                              final e = TimeParser.parseToMs(val);
                              if (e != null) r.endMs = e;
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: r.text,
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: AppColors.surfaceLight,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(5), borderSide: BorderSide.none),
                          ),
                          onChanged: (val) => r.text = val,
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 80,
                        child: ElevatedButton.icon(
                          onPressed: () => _playAudioSlice(r),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPlayingThis ? AppColors.accentOrange : AppColors.surfaceLight,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                          ),
                          icon: Icon(isPlayingThis ? Icons.stop : Icons.play_arrow, size: 14, color: isPlayingThis ? Colors.white : AppColors.accentOrange),
                          label: Text(isPlayingThis ? 'Stop' : 'Play', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _copyTimestamps,
              icon: const Icon(Icons.copy, size: 14, color: AppColors.accentOrange),
              label: const Text('Copy Timestamps', style: TextStyle(fontSize: 11.5, color: Colors.white)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedTargetTrackId,
                decoration: const InputDecoration(labelText: 'Match Timeline', isDense: true),
                items: targetTracks
                    .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name, style: const TextStyle(fontSize: 11.5))))
                    .toList(),
                onChanged: (v) => setState(() => _selectedTargetTrackId = v),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.exportGreen, foregroundColor: Colors.white),
              onPressed: _applyToTimeline,
              icon: const Icon(Icons.check, size: 15),
              label: const Text('Apply to Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
            ),
          ],
        ),
      ],
    );
  }
}
