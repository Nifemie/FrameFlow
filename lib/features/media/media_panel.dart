import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/natural_sort.dart';
import '../../providers/project_provider.dart';
import '../../services/audio_probe_service.dart';
import 'widgets/audio_drop_card.dart';
import 'widgets/image_list_view.dart';
import 'widgets/media_drop_target.dart';

class MediaPanel extends ConsumerWidget {
  const MediaPanel({super.key});

  void _handleDroppedFiles(BuildContext context, List<String> paths, WidgetRef ref) {
    final mediaPaths = <String>[];
    final audioPaths = <String>[];
    final unsupportedFiles = <String>[];

    for (final path in paths) {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) {
        try {
          final dir = Directory(path);
          final folderMedia = <String>[];
          for (final entity in dir.listSync(recursive: true, followLinks: false)) {
            if (entity is File) {
              final ext = p.extension(entity.path).toLowerCase().replaceAll('.', '');
              if (AppConstants.supportedVideoExtensions.contains(ext) || AppConstants.supportedImageExtensions.contains(ext)) {
                folderMedia.add(entity.path);
              } else if (AppConstants.supportedAudioExtensions.contains(ext)) {
                audioPaths.add(entity.path);
              }
            }
          }
          folderMedia.sort((a, b) => NaturalSort.compare(p.basename(a), p.basename(b)));
          mediaPaths.addAll(folderMedia);
        } catch (_) {}
      } else {
        final ext = p.extension(path).toLowerCase().replaceAll('.', '');
        if (AppConstants.supportedVideoExtensions.contains(ext) || AppConstants.supportedImageExtensions.contains(ext)) {
          mediaPaths.add(path);
        } else if (AppConstants.supportedAudioExtensions.contains(ext)) {
          audioPaths.add(path);
        } else {
          unsupportedFiles.add(p.basename(path));
        }
      }
    }

    if (mediaPaths.isNotEmpty) {
      ref.read(projectProvider.notifier).addImages(mediaPaths);
    }
    for (final a in audioPaths) {
      AudioProbeService.getAudioDurationMs(a).then((durationMs) {
        ref.read(projectProvider.notifier).addAudioClip(a, p.basename(a), durationMs);
      });
    }

    if (unsupportedFiles.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.errorRed,
          content: Text(
            '⚠️ ${unsupportedFiles.length} unsupported file(s) skipped: ${unsupportedFiles.take(3).join(", ")}${unsupportedFiles.length > 3 ? "..." : ""}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      child: MediaDropTarget(
        onFilesDropped: (paths) => _handleDroppedFiles(context, paths, ref),
        child: const Column(
          children: [
            AudioDropCard(),
            Divider(height: 1, color: AppColors.surfaceBorder),
            Expanded(child: ImageListView()),
          ],
        ),
      ),
    );
  }
}
