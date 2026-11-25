import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/timeline_track_item.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../services/playback_controller.dart';
import '../../../services/video_playback_engine.dart';
import '../../timestamps/widgets/bulk_timestamp_dialog.dart';
import 'animation_randomisation_dialog.dart';

class TrackHeaderColumn extends ConsumerWidget {
  final ScrollController? scrollController;

  const TrackHeaderColumn({super.key, this.scrollController});

  Future<void> _pickImages(WidgetRef ref, String trackId) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: AppConstants.supportedImageExtensions, allowMultiple: true);
    if (result != null) ref.read(projectProvider.notifier).addImages(result.paths.whereType<String>().toList(), trackId: trackId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    final notifier = ref.read(projectProvider.notifier);
    final tracks = project.effectiveTracks;

    return Container(
      width: 148,
      decoration: const BoxDecoration(color: AppColors.surface, border: Border(right: BorderSide(color: AppColors.surfaceBorder, width: 1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 32, padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.surfaceBorder))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TRACKS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textMuted, letterSpacing: 0.5)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Randomise Animations',
                      icon: const Icon(Icons.auto_awesome, size: 14, color: AppColors.accentOrange),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => showDialog(context: context, builder: (_) => const AnimationRandomisationDialog()),
                    ),
                    const SizedBox(width: 6),
                    PopupMenuButton<String>(
                      tooltip: 'Add Track Layer',
                      icon: const Icon(Icons.add, size: 16, color: AppColors.accentOrange),
                      padding: EdgeInsets.zero,
                      color: AppColors.surface,
                      onSelected: (val) {
                        if (val == 'audio') notifier.addTrack(name: 'Audio Track', type: TrackType.audio);
                        if (val == 'text') notifier.addTrack(name: 'Text / Titles', type: TrackType.text);
                        if (val == 'underlay') notifier.addTrack(name: 'BG (Underlay)', type: TrackType.backgroundUnderlay);
                        if (val == 'overlay') notifier.addTrack(name: 'V2 (Overlay)', type: TrackType.overlayVideo);
                      },
                      itemBuilder: (_) => [
                        if (!tracks.any((t) => t.type == TrackType.audio))
                          const PopupMenuItem(value: 'audio', child: Text('+ Audio / Music Track', style: TextStyle(fontSize: 11, color: Colors.white))),
                        if (!tracks.any((t) => t.type == TrackType.text))
                          const PopupMenuItem(value: 'text', child: Text('+ Text / Titles Track', style: TextStyle(fontSize: 11, color: Colors.white))),
                        if (!tracks.any((t) => t.type == TrackType.backgroundUnderlay))
                          const PopupMenuItem(value: 'underlay', child: Text('+ Background Underlay Track', style: TextStyle(fontSize: 11, color: Colors.white))),
                        const PopupMenuItem(value: 'overlay', child: Text('+ Video Overlay Track', style: TextStyle(fontSize: 11, color: Colors.white))),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.separated(
              controller: scrollController,
              padding: EdgeInsets.zero, itemCount: tracks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, idx) {
                final tr = tracks[idx];
                final canDelete = tr.type != TrackType.mainVideo;
                final isVideo = tr.isVideoOrBg;
                final badgeColor = tr.type == TrackType.overlayVideo ? Colors.cyanAccent : (tr.type == TrackType.backgroundUnderlay ? Colors.purpleAccent : (tr.type == TrackType.text ? Colors.amber : (tr.type == TrackType.audio ? AppColors.waveform : AppColors.clipBlue)));

                return _buildRow(
                  context: context, label: tr.name, height: isVideo ? 64 : (tr.type == TrackType.text ? 32 : 38),
                  isVisible: tr.isVisible, isMuted: tr.isMuted, badgeColor: badgeColor,
                  onTap: () {
                    if (tr.type == TrackType.audio) {
                      final clips = ref.read(projectProvider).effectiveAudioClips;
                      if (clips.isNotEmpty) {
                        ref.read(selectedAudioClipIdProvider.notifier).state = clips.first.id;
                        ref.read(selectedImageIdProvider.notifier).state = null;
                        ref.read(selectedClipIdsProvider.notifier).state = {};
                        ref.read(selectedTextOverlayIdProvider.notifier).state = null;
                      }
                    }
                  },
                  onToggleVis: () => notifier.toggleTrackVisibility(tr.id),
                  onToggleMute: tr.canMute
                      ? () {
                          notifier.toggleTrackMute(tr.id);
                          final willBeMuted = !tr.isMuted;
                          if (tr.type == TrackType.audio) {
                            ref.read(playbackControllerProvider).setLiveVolume(willBeMuted ? 0.0 : 1.0);
                          } else {
                            VideoPlaybackEngine.setVolume(willBeMuted ? 0.0 : 100.0);
                          }
                        }
                      : null,
                  onAddMedia: isVideo ? () => _pickImages(ref, tr.id) : null,
                  onAddBg: isVideo ? () => notifier.addColorBackground(trackId: tr.id) : null,
                  onTimestamp: (isVideo || tr.type == TrackType.audio)
                      ? () => showDialog(
                            context: context,
                            builder: (_) => BulkTimestampDialog(
                              trackId: tr.id,
                              trackName: tr.name,
                              isAudio: tr.type == TrackType.audio,
                            ),
                          )
                      : null,
                  onDelete: canDelete ? () => notifier.removeTrack(tr.id) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow({
    required BuildContext context, required String label, required double height, required bool isVisible,
    required bool isMuted, required Color badgeColor, required VoidCallback onToggleVis, VoidCallback? onToggleMute,
    VoidCallback? onAddMedia, VoidCallback? onAddBg, VoidCallback? onTimestamp, VoidCallback? onDelete,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: height, padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.surfaceBorder, width: 0.5)),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(width: 3, height: 12, decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(1.5))),
              const SizedBox(width: 4),
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
              IconButton(icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off, size: 13, color: isVisible ? AppColors.textPrimary : AppColors.textMuted), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onToggleVis),
              if (height <= 40 && onTimestamp != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Set / Import Timestamps',
                  icon: const Icon(Icons.access_time, size: 13, color: AppColors.accentOrange),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onTimestamp,
                ),
              ],
              if (onToggleMute != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: isMuted ? 'Unmute Track' : 'Mute Track',
                  icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up, size: 13, color: isMuted ? AppColors.errorRed : AppColors.textPrimary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onToggleMute,
                ),
              ],
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                IconButton(icon: const Icon(Icons.close, size: 12, color: AppColors.textMuted), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onDelete),
              ],
            ],
          ),
          if (height > 40) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                if (onTimestamp != null) IconButton(tooltip: 'Import Timestamps', icon: const Icon(Icons.access_time, size: 13, color: AppColors.accentOrange), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onTimestamp),
                if (onAddBg != null) ...[
                  const SizedBox(width: 6),
                  IconButton(tooltip: 'Add Solid Color Background', icon: const Icon(Icons.palette_outlined, size: 13, color: Colors.purpleAccent), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onAddBg),
                ],
                if (onAddMedia != null) ...[
                  const SizedBox(width: 6),
                  IconButton(tooltip: 'Add Media / Images', icon: const Icon(Icons.add_photo_alternate_outlined, size: 13, color: AppColors.clipBlueLight), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: onAddMedia),
                ],
              ],
            ),
          ],
        ],
      ),
    ),
  );
}
}
