import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';
import '../../../models/audio_clip_item.dart';
import '../../../models/image_item.dart';
import '../../../models/text_overlay_item.dart';
import '../../../models/timeline_track_item.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../services/playback_controller.dart';
import '../../../services/video_playback_engine.dart';
import '../../properties/widgets/video_range_dialog.dart';
import '../../timestamps/widgets/bulk_timestamp_dialog.dart';
import 'animation_randomisation_dialog.dart';
import 'audio_volume_dialog.dart';

/// Unified right-click context menu builder for all asset types (Images, Videos, Text, Audio).
class AssetContextMenus {
  static Future<void> showMediaClipMenu({
    required BuildContext context,
    required WidgetRef ref,
    required Offset globalPosition,
    required ImageItem item,
  }) async {
    SelectionHelper.selectImage(ref, item.id);
    final notifier = ref.read(projectProvider.notifier);
    final playhead = ref.read(playheadPositionProvider);

    final selected = await showMenu<String>(
      context: context,
      color: AppColors.surface,
      position: RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy, globalPosition.dx, globalPosition.dy),
      items: [
        const PopupMenuItem(
          value: 'properties',
          child: Row(children: [Icon(Icons.tune, size: 15, color: AppColors.clipBlueLight), SizedBox(width: 8), Text('Show Properties', style: TextStyle(fontSize: 12, color: Colors.white))]),
        ),
        const PopupMenuItem(
          value: 'edit_time',
          child: Row(children: [Icon(Icons.schedule, size: 15, color: Colors.white70), SizedBox(width: 8), Text('Change Start / End Time...', style: TextStyle(fontSize: 12, color: Colors.white))]),
        ),
        if (item.isVideo) ...[
          const PopupMenuItem(
            value: 'video_range',
            child: Row(children: [Icon(Icons.movie_filter_outlined, size: 15, color: AppColors.accentOrange), SizedBox(width: 8), Text('Set Video Range (In / Out)...', style: TextStyle(fontSize: 12, color: Colors.white))]),
          ),
          PopupMenuItem(
            value: 'toggle_mute',
            child: Row(children: [
              Icon(item.isMuted ? Icons.volume_up : Icons.volume_off, size: 15, color: item.isMuted ? AppColors.exportGreen : AppColors.errorRed),
              const SizedBox(width: 8),
              Text(item.isMuted ? 'Unmute Video Audio' : 'Mute Video Audio', style: const TextStyle(fontSize: 12, color: Colors.white)),
            ]),
          ),
        ],
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'split',
          child: Row(children: [Icon(Icons.content_cut, size: 15, color: AppColors.clipBlueLight), SizedBox(width: 8), Text('Split at Playhead (S)', style: TextStyle(fontSize: 12, color: Colors.white))]),
        ),
        const PopupMenuItem(
          value: 'duplicate',
          child: Row(children: [Icon(Icons.copy, size: 15, color: Colors.white70), SizedBox(width: 8), Text('Duplicate Clip (Ctrl+D)', style: TextStyle(fontSize: 12, color: Colors.white))]),
        ),
        PopupMenuItem(
          value: 'mark',
          child: Row(children: [
            Icon(item.isMarked ? Icons.bookmark_remove : Icons.bookmark_add, size: 15, color: Colors.amber),
            const SizedBox(width: 8),
            Text(item.isMarked ? 'Unmark Asset' : 'Mark Asset', style: const TextStyle(fontSize: 12, color: Colors.white)),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete_gap',
          child: Row(children: [Icon(Icons.delete_outline, size: 15, color: AppColors.errorRed), SizedBox(width: 8), Text('Delete (Keep Blank Space)', style: TextStyle(fontSize: 12, color: AppColors.errorRed))]),
        ),
        const PopupMenuItem(
          value: 'delete_ripple',
          child: Row(children: [Icon(Icons.delete_sweep_outlined, size: 15, color: AppColors.errorRed), SizedBox(width: 8), Text('Ripple Delete (Close Gap)', style: TextStyle(fontSize: 12, color: AppColors.errorRed))]),
        ),
      ],
    );

    if (!context.mounted || selected == null) return;
    switch (selected) {
      case 'edit_time':
        _showEditClipTimeDialog(context, ref, item);
        break;
      case 'video_range':
        showDialog(context: context, builder: (_) => VideoRangeDialog(item: item));
        break;
      case 'toggle_mute':
        notifier.toggleImageMute(item.id);
        VideoPlaybackEngine.setVolume(!item.isMuted ? 0.0 : 100.0);
        break;
      case 'split':
        final ok = notifier.splitAtPlayhead(playhead);
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Position playhead inside clip (>100ms from edges) to split')),
          );
        }
        break;
      case 'duplicate':
        notifier.duplicateImage(item.id);
        break;
      case 'mark':
        notifier.toggleAssetMark(item.id);
        break;
      case 'delete_gap':
        notifier.removeImage(item.id, preserveGap: true);
        SelectionHelper.clearAll(ref);
        break;
      case 'delete_ripple':
        notifier.removeImage(item.id, preserveGap: false);
        SelectionHelper.clearAll(ref);
        break;
    }
  }

  static Future<void> showTextOverlayMenu({
    required BuildContext context,
    required WidgetRef ref,
    required Offset globalPosition,
    required TextOverlayItem item,
  }) async {
    SelectionHelper.selectTextOverlay(ref, item.id);
    final notifier = ref.read(projectProvider.notifier);

    final selected = await showMenu<String>(
      context: context,
      color: AppColors.surface,
      position: RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy, globalPosition.dx, globalPosition.dy),
      items: [
        const PopupMenuItem(
          value: 'properties',
          child: Row(children: [Icon(Icons.tune, size: 15, color: Colors.amber), SizedBox(width: 8), Text('Show Text Properties', style: TextStyle(fontSize: 12, color: Colors.white))]),
        ),
        const PopupMenuItem(
          value: 'edit_time',
          child: Row(children: [Icon(Icons.schedule, size: 15, color: Colors.white70), SizedBox(width: 8), Text('Change Start / Duration...', style: TextStyle(fontSize: 12, color: Colors.white))]),
        ),
        const PopupMenuItem(
          value: 'duplicate',
          child: Row(children: [Icon(Icons.copy, size: 15, color: Colors.white70), SizedBox(width: 8), Text('Duplicate Text', style: TextStyle(fontSize: 12, color: Colors.white))]),
        ),
        PopupMenuItem(
          value: 'mark',
          child: Row(children: [
            Icon(item.isMarked ? Icons.bookmark_remove : Icons.bookmark_add, size: 15, color: Colors.amber),
            const SizedBox(width: 8),
            Text(item.isMarked ? 'Unmark Text' : 'Mark Text', style: const TextStyle(fontSize: 12, color: Colors.white)),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [Icon(Icons.delete_outline, size: 15, color: AppColors.errorRed), SizedBox(width: 8), Text('Delete Text', style: TextStyle(fontSize: 12, color: AppColors.errorRed))]),
        ),
      ],
    );

    if (!context.mounted || selected == null) return;
    switch (selected) {
      case 'edit_time':
        _showEditTextTimeDialog(context, ref, item);
        break;
      case 'duplicate':
        final copy = item.copyWith(
          id: '${item.id}_copy_${DateTime.now().millisecondsSinceEpoch}',
          startMs: item.endMs,
        );
        notifier.addTextOverlay(copy);
        break;
      case 'mark':
        notifier.toggleAssetMark(item.id);
        break;
      case 'delete':
        notifier.deleteTextOverlay(item.id);
        SelectionHelper.clearAll(ref);
        break;
    }
  }

  static Future<void> showAudioClipMenu({
    required BuildContext context,
    required WidgetRef ref,
    required Offset globalPosition,
    required AudioClipItem clip,
  }) async {
    SelectionHelper.selectAudioClip(ref, clip.id);
    final notifier = ref.read(projectProvider.notifier);
    final playhead = ref.read(playheadPositionProvider);

    final selected = await showMenu<String>(
      context: context,
      color: AppColors.surface,
      position: RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy, globalPosition.dx, globalPosition.dy),
      items: [
        const PopupMenuItem(
          value: 'properties',
          child: Row(children: [Icon(Icons.tune, size: 15, color: AppColors.waveform), SizedBox(width: 8), Text('Show Audio Properties', style: TextStyle(fontSize: 12, color: Colors.white))]),
        ),
        const PopupMenuItem(
          value: 'volume',
          child: Row(children: [Icon(Icons.volume_up, size: 15, color: AppColors.waveform), SizedBox(width: 8), Text('Adjust Volume...', style: TextStyle(fontSize: 12, color: Colors.white))]),
        ),
        const PopupMenuItem(
          value: 'split',
          child: Row(children: [Icon(Icons.content_cut, size: 15, color: AppColors.clipBlueLight), SizedBox(width: 8), Text('Split Audio at Playhead (S)', style: TextStyle(fontSize: 12, color: Colors.white))]),
        ),
        PopupMenuItem(
          value: 'mark',
          child: Row(children: [
            Icon(clip.isMarked ? Icons.bookmark_remove : Icons.bookmark_add, size: 15, color: Colors.amber),
            const SizedBox(width: 8),
            Text(clip.isMarked ? 'Unmark Audio' : 'Mark Audio', style: const TextStyle(fontSize: 12, color: Colors.white)),
          ]),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Row(children: [Icon(Icons.delete_outline, size: 15, color: AppColors.errorRed), SizedBox(width: 8), Text('Delete Audio Clip', style: TextStyle(fontSize: 12, color: AppColors.errorRed))]),
        ),
      ],
    );

    if (!context.mounted || selected == null) return;
    switch (selected) {
      case 'volume':
        showDialog(context: context, builder: (_) => AudioVolumeDialog(clip: clip));
        break;
      case 'split':
        notifier.splitSpecificAudioClip(clip.id, atTimelineMs: playhead);
        break;
      case 'mark':
        notifier.toggleAssetMark(clip.id);
        break;
      case 'delete':
        notifier.deleteAudioClip(clip.id);
        SelectionHelper.clearAll(ref);
        break;
    }
  }

  static void _showEditClipTimeDialog(BuildContext context, WidgetRef ref, ImageItem item) {
    final startCtrl = TextEditingController(text: TimeParser.formatStandard(item.startMs));
    final endCtrl = TextEditingController(text: TimeParser.formatStandard(item.endMs));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Change Clip Timing', style: TextStyle(fontSize: 14, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Start Time (e.g. 00:05)'), style: const TextStyle(fontFamily: 'Consolas', color: Colors.white)),
            const SizedBox(height: 10),
            TextField(controller: endCtrl, decoration: const InputDecoration(labelText: 'End Time (e.g. 00:12)'), style: const TextStyle(fontFamily: 'Consolas', color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final notifier = ref.read(projectProvider.notifier);
              notifier.updateStartTimestamp(item.id, startCtrl.text.trim());
              notifier.updateTimestamp(item.id, endCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  static void _showEditTextTimeDialog(BuildContext context, WidgetRef ref, TextOverlayItem item) {
    final startCtrl = TextEditingController(text: TimeParser.formatStandard(item.startMs));
    final durCtrl = TextEditingController(text: (item.durationMs / 1000).toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Change Text Timing', style: TextStyle(fontSize: 14, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Start Time (e.g. 00:05)'), style: const TextStyle(fontFamily: 'Consolas', color: Colors.white)),
            const SizedBox(height: 10),
            TextField(controller: durCtrl, decoration: const InputDecoration(labelText: 'Duration (seconds, e.g. 3.5)'), style: const TextStyle(fontFamily: 'Consolas', color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final s = TimeParser.parseToMs(startCtrl.text);
              final dSec = double.tryParse(durCtrl.text.trim());
              ref.read(projectProvider.notifier).trimTextOverlay(
                item.id,
                startMs: s,
                durationMs: dSec != null ? (dSec * 1000).round().clamp(200, 3600000) : null,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  /// Right-click context menu for an entire timeline track (affects the whole timeline).
  static Future<void> showTimelineMenu({
    required BuildContext context,
    required WidgetRef ref,
    required Offset globalPosition,
    required TimelineTrackItem track,
    int? emptyStartMs,
    int? emptyEndMs,
    VoidCallback? onFillEmptyWithMedia,
    VoidCallback? onFillEmptyWithColor,
    VoidCallback? onAddMedia,
    VoidCallback? onAddFolder,
    VoidCallback? onAddBg,
  }) async {
    final notifier = ref.read(projectProvider.notifier);
    final isMedia = track.isVideoOrBg;
    final hasEmptyRange = isMedia && emptyStartMs != null && emptyEndMs != null && emptyEndMs > emptyStartMs;
    final emptyLabel = hasEmptyRange
        ? '${TimeParser.formatStandard(emptyStartMs)} → ${TimeParser.formatStandard(emptyEndMs)}'
        : '';

    final selected = await showMenu<String>(
      context: context,
      color: AppColors.surface,
      position: RelativeRect.fromLTRB(globalPosition.dx, globalPosition.dy, globalPosition.dx, globalPosition.dy),
      items: [
        if (hasEmptyRange && onFillEmptyWithMedia != null)
          PopupMenuItem(
            value: 'fill_empty_media',
            child: Row(children: [const Icon(Icons.add_photo_alternate, size: 15, color: AppColors.clipBlueLight), const SizedBox(width: 8), Text('Fill Space ($emptyLabel) with Image/Video...', style: const TextStyle(fontSize: 12, color: Colors.white))]),
          ),
        if (hasEmptyRange && onFillEmptyWithColor != null)
          PopupMenuItem(
            value: 'fill_empty_color',
            child: Row(children: [const Icon(Icons.palette, size: 15, color: Colors.purpleAccent), const SizedBox(width: 8), Text('Fill Space ($emptyLabel) with Background', style: const TextStyle(fontSize: 12, color: Colors.white))]),
          ),
        if (hasEmptyRange) const PopupMenuDivider(),
        if (isMedia && onAddMedia != null)
          const PopupMenuItem(
            value: 'add_media',
            child: Row(children: [Icon(Icons.add_photo_alternate_outlined, size: 15, color: AppColors.clipBlueLight), SizedBox(width: 8), Text('Add Videos / Images...', style: TextStyle(fontSize: 12, color: Colors.white))]),
          ),
        if (isMedia && onAddFolder != null)
          const PopupMenuItem(
            value: 'add_folder',
            child: Row(children: [Icon(Icons.folder_open, size: 15, color: AppColors.accentOrange), SizedBox(width: 8), Text('Import Folder of Media...', style: TextStyle(fontSize: 12, color: Colors.white))]),
          ),
        if (isMedia && onAddBg != null)
          const PopupMenuItem(
            value: 'add_bg',
            child: Row(children: [Icon(Icons.palette_outlined, size: 15, color: Colors.purpleAccent), SizedBox(width: 8), Text('Add Solid Color Background', style: TextStyle(fontSize: 12, color: Colors.white))]),
          ),
        if (isMedia)
          const PopupMenuItem(
            value: 'create_blank',
            child: Row(children: [Icon(Icons.space_bar, size: 15, color: Colors.white70), SizedBox(width: 8), Text('Create Blank Space at Playhead...', style: TextStyle(fontSize: 12, color: Colors.white))]),
          ),
        if (isMedia) const PopupMenuDivider(),
        if (isMedia)
          const PopupMenuItem(
            value: 'randomize_anim',
            child: Row(children: [Icon(Icons.auto_awesome, size: 15, color: AppColors.accentOrange), SizedBox(width: 8), Text('Randomize Animations...', style: TextStyle(fontSize: 12, color: Colors.white))]),
          ),
        if (isMedia || track.type == TrackType.audio)
          const PopupMenuItem(
            value: 'bulk_timestamps',
            child: Row(children: [Icon(Icons.access_time, size: 15, color: AppColors.accentOrange), SizedBox(width: 8), Text('Bulk Set / Import Timestamps...', style: TextStyle(fontSize: 12, color: Colors.white))]),
          ),
        if (isMedia)
          const PopupMenuItem(
            value: 'pack_left',
            child: Row(children: [Icon(Icons.format_align_left, size: 15, color: Colors.cyanAccent), SizedBox(width: 8), Text('Auto-Rearrange from Left (Pack)', style: TextStyle(fontSize: 12, color: Colors.white))]),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'toggle_vis',
          child: Row(children: [
            Icon(track.isVisible ? Icons.visibility_off : Icons.visibility, size: 15, color: Colors.white70),
            const SizedBox(width: 8),
            Text(track.isVisible ? 'Hide Timeline' : 'Show Timeline', style: const TextStyle(fontSize: 12, color: Colors.white)),
          ]),
        ),
        if (track.canMute)
          PopupMenuItem(
            value: 'toggle_mute',
            child: Row(children: [
              Icon(track.isMuted ? Icons.volume_up : Icons.volume_off, size: 15, color: track.isMuted ? AppColors.exportGreen : AppColors.errorRed),
              const SizedBox(width: 8),
              Text(track.isMuted ? 'Unmute Timeline Audio' : 'Mute Timeline Audio', style: const TextStyle(fontSize: 12, color: Colors.white)),
            ]),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete_track',
          child: Row(children: [Icon(Icons.delete_outline, size: 15, color: AppColors.errorRed), SizedBox(width: 8), Text('Delete / Clear Timeline', style: TextStyle(fontSize: 12, color: AppColors.errorRed))]),
        ),
      ],
    );

    if (!context.mounted || selected == null) return;
    switch (selected) {
      case 'fill_empty_media':
        onFillEmptyWithMedia?.call();
        break;
      case 'fill_empty_color':
        onFillEmptyWithColor?.call();
        break;
      case 'add_media':
        onAddMedia?.call();
        break;
      case 'add_folder':
        onAddFolder?.call();
        break;
      case 'add_bg':
        onAddBg?.call();
        break;
      case 'create_blank':
        _showCreateBlankDialog(context, ref, track.id);
        break;
      case 'randomize_anim':
        showDialog(context: context, builder: (_) => const AnimationRandomisationDialog());
        break;
      case 'bulk_timestamps':
        showDialog(
          context: context,
          builder: (_) => BulkTimestampDialog(
            trackId: track.id,
            trackName: track.name,
            isAudio: track.type == TrackType.audio,
          ),
        );
        break;
      case 'pack_left':
        notifier.autoArrangeFromLeft(trackId: track.id);
        break;
      case 'toggle_vis':
        notifier.toggleTrackVisibility(track.id);
        break;
      case 'toggle_mute':
        notifier.toggleTrackMute(track.id);
        final willBeMuted = !track.isMuted;
        if (track.type == TrackType.audio) {
          ref.read(playbackControllerProvider).setLiveVolume(willBeMuted ? 0.0 : 1.0);
        } else {
          VideoPlaybackEngine.setVolume(willBeMuted ? 0.0 : 100.0);
        }
        break;
      case 'delete_track':
        notifier.removeTrack(track.id);
        break;
    }
  }

  static void _showCreateBlankDialog(BuildContext context, WidgetRef ref, String trackId) {
    final durCtrl = TextEditingController(text: '3.0');
    final playheadMs = ref.read(playheadPositionProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Create Blank Space', style: TextStyle(fontSize: 14, color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Insert blank space at ${TimeParser.formatStandard(playheadMs)}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: durCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontFamily: 'Consolas', color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Duration (seconds)',
                hintText: '3.0',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final sec = double.tryParse(durCtrl.text.trim());
              if (sec != null && sec >= 0.2) {
                ref.read(projectProvider.notifier).createBlankAtPlayhead(
                  trackId,
                  playheadMs,
                  durationMs: (sec * 1000).round(),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create Blank'),
          ),
        ],
      ),
    );
  }
}
