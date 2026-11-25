import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/image_item.dart';
import '../../../providers/project_provider.dart';
import '../../../services/video_metadata_service.dart';

class ClipInsertButton extends ConsumerWidget {
  final ImageItem afterClip;

  const ClipInsertButton({super.key, required this.afterClip});

  Future<void> _pickVideos(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.supportedVideoExtensions,
      allowMultiple: true,
    );
    if (result != null && result.paths.isNotEmpty) {
      for (final p in result.paths.whereType<String>()) {
        await VideoMetadataService.resolveDuration(p);
        ref.read(projectProvider.notifier).insertAssetAfterClip(
          afterClip: afterClip,
          isColorBg: false,
          imagePath: p,
        );
      }
    }
  }

  Future<void> _pickImages(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: AppConstants.supportedImageExtensions, allowMultiple: true);
    if (result != null && result.paths.isNotEmpty) {
      for (final p in result.paths.whereType<String>()) {
        ref.read(projectProvider.notifier).insertAssetAfterClip(afterClip: afterClip, isColorBg: false, imagePath: p);
      }
    }
  }

  void _addColorBg(WidgetRef ref) {
    ref.read(projectProvider.notifier).insertAssetAfterClip(afterClip: afterClip, isColorBg: true, color: const Color(0xFF4F46E5));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Insert Asset / Fill Next Gap',
      padding: EdgeInsets.zero,
      color: AppColors.surface,
      offset: const Offset(0, 24),
      onSelected: (val) {
        if (val == 'video') _pickVideos(context, ref);
        if (val == 'image') _pickImages(context, ref);
        if (val == 'color') _addColorBg(ref);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'video',
          child: Row(
            children: [
              Icon(Icons.videocam_rounded, size: 14, color: AppColors.accentOrange),
              SizedBox(width: 8),
              Text('+ Insert Video(s)', style: TextStyle(fontSize: 11, color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'image',
          child: Row(
            children: [
              Icon(Icons.add_photo_alternate, size: 14, color: AppColors.clipBlue),
              SizedBox(width: 8),
              Text('+ Insert Image(s)', style: TextStyle(fontSize: 11, color: Colors.white)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'color',
          child: Row(
            children: [
              Icon(Icons.palette_outlined, size: 14, color: Colors.purpleAccent),
              SizedBox(width: 8),
              Text('+ Color Background / Matte', style: TextStyle(fontSize: 11, color: Colors.white)),
            ],
          ),
        ),
      ],
      child: Container(
        width: 18, height: 18,
        decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))]),
        child: const Center(child: Icon(Icons.add, size: 13, color: Colors.white)),
      ),
    );
  }
}
