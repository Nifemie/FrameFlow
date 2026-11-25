import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_parser.dart';
import '../../models/image_item.dart';
import '../../providers/project_provider.dart';
import '../../providers/selection_provider.dart';
import '../../services/video_playback_engine.dart';
import 'widgets/alignment_toolbar.dart';
import 'widgets/asset_animation_editor.dart';
import 'widgets/audio_properties_editor.dart';
import 'widgets/fit_mode_selector.dart';
import 'widgets/inline_color_picker.dart';
import 'widgets/text_properties_editor.dart';
import 'widgets/timestamp_editor.dart';
import 'widgets/video_range_dialog.dart';

class PropertiesPanel extends ConsumerWidget {
  const PropertiesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedImageIdProvider);
    final selectedTextId = ref.watch(selectedTextOverlayIdProvider);
    final selectedAudioId = ref.watch(selectedAudioClipIdProvider);
    final project = ref.watch(projectProvider);

    if (selectedAudioId != null && project.effectiveAudioClips.isNotEmpty) {
      final audioClip = project.effectiveAudioClips.where((c) => c.id == selectedAudioId).firstOrNull ??
          project.effectiveAudioClips.firstOrNull;
      if (audioClip != null) {
        return Container(
          width: 260,
          decoration: const BoxDecoration(color: AppColors.surface, border: Border(left: BorderSide(color: AppColors.surfaceBorder, width: 1))),
          child: AudioPropertiesEditor(clip: audioClip),
        );
      }
    }

    if (selectedTextId != null && project.textOverlays.isNotEmpty) {
      final textItem = project.textOverlays.where((t) => t.id == selectedTextId).firstOrNull;
      if (textItem != null) {
        return Container(
          width: 260,
          decoration: const BoxDecoration(color: AppColors.surface, border: Border(left: BorderSide(color: AppColors.surfaceBorder, width: 1))),
          child: TextPropertiesEditor(item: textItem),
        );
      }
    }

    ImageItem? selectedItem;
    bool isLast = false;
    if (selectedId != null && project.images.isNotEmpty) {
      final index = project.images.indexWhere((img) => img.id == selectedId);
      if (index != -1) {
        selectedItem = project.images[index];
        isLast = (index == project.images.length - 1);
      }
    }

    return Container(
      width: 260,
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(left: BorderSide(color: AppColors.surfaceBorder, width: 1))),
      child: selectedItem == null
          ? const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Select an image, background, or text overlay', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textMuted))))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text(selectedItem.isColorBackground ? 'Color Background #${selectedItem.orderIndex + 1}' : 'Clip #${selectedItem.orderIndex + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.clipBlueLight)),
                const SizedBox(height: 2),
                Text(selectedItem.isColorBackground ? 'Solid Color Background' : selectedItem.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.surfaceBorder),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStatChip('Start', TimeParser.formatStandard(selectedItem.startMs)),
                    const SizedBox(width: 8),
                    _buildStatChip('End', TimeParser.formatStandard(selectedItem.endMs)),
                    const SizedBox(width: 8),
                    _buildStatChip('Duration', '${(selectedItem.durationMs / 1000).toStringAsFixed(1)}s'),
                  ],
                ),
                const SizedBox(height: 16),
                TimestampEditor(item: selectedItem, isLastImage: isLast, hasVoiceOver: project.voiceOver != null),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.surfaceBorder),
                const SizedBox(height: 12),
                if (selectedItem.isColorBackground) ...[
                  const Text('Background Color', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70)),
                  InlineColorPicker(
                    title: 'Background Color',
                    currentColor: selectedItem.backgroundColor ?? const Color(0xFF1E293B),
                    onColorChanged: (c) => ref.read(projectProvider.notifier).updateImageColor(selectedItem!.id, c, recordUndo: false),
                  ),
                ] else
                  FitModeSelector(currentMode: selectedItem.fitMode, onModeChanged: (mode) => ref.read(projectProvider.notifier).updateFitMode(selectedItem!.id, mode)),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.surfaceBorder),
                const SizedBox(height: 12),
                const AlignmentToolbar(),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.surfaceBorder),
                const SizedBox(height: 12),
                AssetAnimationEditor(item: selectedItem),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.surfaceBorder),
                const SizedBox(height: 10),
                if (selectedItem.isVideo) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Video Source Range', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accentOrange)),
                            if (selectedItem.sourceDurationMs != null && selectedItem.sourceDurationMs! > 0)
                              Text(
                                'Total: ${TimeParser.formatStandard(selectedItem.sourceDurationMs!)}',
                                style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${TimeParser.formatStandard(selectedItem.sourceStartOffsetMs)} → ${TimeParser.formatStandard(selectedItem.sourceStartOffsetMs + selectedItem.durationMs)}',
                          style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          height: 28,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              side: const BorderSide(color: AppColors.accentOrange),
                            ),
                            icon: const Icon(Icons.movie_filter_outlined, size: 13, color: AppColors.accentOrange),
                            label: const Text('Cut / Set Range (In - Out)', style: TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.bold)),
                            onPressed: () => showDialog(context: context, builder: (_) => VideoRangeDialog(item: selectedItem!)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      final isMuted = selectedItem!.isMuted || project.isTrackMuted(selectedItem.trackId);
                      return SizedBox(
                        width: double.infinity,
                        height: 36,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMuted
                                ? AppColors.errorRed.withValues(alpha: 0.15)
                                : AppColors.surfaceLight,
                            foregroundColor: isMuted ? AppColors.errorRed : Colors.white,
                            side: BorderSide(
                              color: isMuted ? AppColors.errorRed : AppColors.accentOrange,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                          icon: Icon(
                            isMuted ? Icons.volume_off : Icons.volume_up,
                            size: 16,
                            color: isMuted ? AppColors.errorRed : AppColors.accentOrange,
                          ),
                          label: Text(
                            isMuted ? 'Unmute Video Audio' : 'Mute Video Audio',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isMuted ? AppColors.errorRed : Colors.white,
                            ),
                          ),
                          onPressed: () {
                            if (isMuted) {
                              if (project.isTrackMuted(selectedItem!.trackId)) {
                                ref.read(projectProvider.notifier).toggleTrackMute(selectedItem.trackId);
                              }
                              if (selectedItem.isMuted) {
                                ref.read(projectProvider.notifier).toggleImageMute(selectedItem.id);
                              }
                              VideoPlaybackEngine.setVolume(100.0);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('🔊 Video audio unmuted'), duration: Duration(seconds: 1)),
                              );
                            } else {
                              ref.read(projectProvider.notifier).toggleImageMute(selectedItem!.id);
                              VideoPlaybackEngine.setVolume(0.0);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('🔇 Video audio muted'), duration: Duration(seconds: 1)),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6), side: const BorderSide(color: AppColors.clipBlue)),
                        icon: const Icon(Icons.content_cut, size: 12, color: AppColors.clipBlueLight),
                        label: const Text('Split (S)', style: TextStyle(fontSize: 10, color: Colors.white)),
                        onPressed: () {
                          final playhead = ref.read(playheadPositionProvider);
                          final ok = ref.read(projectProvider.notifier).splitAtPlayhead(playhead);
                          if (!ok) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Position playhead inside clip (>100ms from edges) to split')));
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6), side: const BorderSide(color: AppColors.surfaceBorder)),
                        icon: const Icon(Icons.copy, size: 12, color: AppColors.textSecondary),
                        label: const Text('Copy (D)', style: TextStyle(fontSize: 10, color: Colors.white)),
                        onPressed: () => ref.read(projectProvider.notifier).duplicateImage(selectedItem!.id),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6), side: BorderSide(color: AppColors.errorRed.withValues(alpha: 0.5))),
                  icon: const Icon(Icons.delete_outline, size: 12, color: AppColors.errorRed),
                  label: const Text('Delete Clip (Del)', style: TextStyle(fontSize: 10, color: AppColors.errorRed)),
                  onPressed: () {
                    ref.read(projectProvider.notifier).removeImage(selectedItem!.id);
                    ref.read(selectedImageIdProvider.notifier).state = null;
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.surfaceBorder)),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
