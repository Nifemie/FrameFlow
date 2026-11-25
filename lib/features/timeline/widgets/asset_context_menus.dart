import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';
import '../../../models/audio_clip_item.dart';
import '../../../models/image_item.dart';
import '../../../models/text_overlay_item.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../services/video_playback_engine.dart';
import '../../properties/widgets/video_range_dialog.dart';
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
}
