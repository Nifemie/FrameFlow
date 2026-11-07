import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/project_provider.dart';
import 'widgets/audio_drop_card.dart';
import 'widgets/image_list_view.dart';
import 'widgets/media_drop_target.dart';

class MediaPanel extends ConsumerWidget {
  const MediaPanel({super.key});

  void _handleDroppedFiles(List<String> paths, WidgetRef ref) {
    final imagePaths = <String>[];
    for (final path in paths) {
      final ext = p.extension(path).toLowerCase().replaceAll('.', '');
      if (AppConstants.supportedImageExtensions.contains(ext)) {
        imagePaths.add(path);
      }
    }
    if (imagePaths.isNotEmpty) {
      ref.read(projectProvider.notifier).addImages(imagePaths);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      child: MediaDropTarget(
        onFilesDropped: (paths) => _handleDroppedFiles(paths, ref),
        child: const Column(
          children: [
            // Voice-Over Section
            AudioDropCard(),

            Divider(height: 1, color: AppColors.surfaceBorder),

            // Image List Section
            Expanded(
              child: ImageListView(),
            ),
          ],
        ),
      ),
    );
  }
}
