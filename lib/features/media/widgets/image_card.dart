import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';
import '../../../models/image_item.dart';
import '../../../services/video_metadata_service.dart';

class ImageCard extends StatelessWidget {
  final ImageItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const ImageCard({super.key, required this.item, required this.isSelected, required this.onTap, required this.onRemove});

  Widget _buildVideoThumbnail(BuildContext context) {
    final thumb = VideoMetadataService.getCachedThumbnail(item.filePath);
    if (thumb != null && File(thumb).existsSync()) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(thumb), cacheWidth: 100, fit: BoxFit.cover),
          Container(color: Colors.black38),
          const Center(child: Icon(Icons.play_circle_fill_rounded, size: 16, color: AppColors.accentOrange)),
        ],
      );
    }
    // Lazy extract thumbnail in background
    VideoMetadataService.getThumbnailPath(item.filePath);
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Icon(Icons.videocam_rounded, size: 20, color: AppColors.accentOrange),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.surfaceLight : AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected ? AppColors.accentOrange : AppColors.surfaceBorder,
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              Container(
                width: 22, height: 22, alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(4)),
                child: Text('${item.orderIndex + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 48, height: 36,
                  child: item.isColorBackground
                      ? Container(color: item.backgroundColor ?? Colors.black, child: const Icon(Icons.palette_outlined, size: 18, color: Colors.white70))
                      : (item.isVideo
                          ? _buildVideoThumbnail(context)
                          : Image.file(File(item.filePath), cacheWidth: 100, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: AppColors.background, child: const Icon(Icons.broken_image, size: 18, color: AppColors.textMuted)))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (item.isVideo)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentOrange.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(color: AppColors.accentOrange, width: 0.5),
                            ),
                            child: const Text('VIDEO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.accentOrange)),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: item.trackId == 'track_bg' ? Colors.purpleAccent.withValues(alpha: 0.25) : AppColors.clipBlue.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(color: item.trackId == 'track_bg' ? Colors.purpleAccent : AppColors.clipBlue, width: 0.5),
                            ),
                            child: Text(item.trackId == 'track_bg' ? 'BG' : 'V1', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: item.trackId == 'track_bg' ? Colors.purpleAccent : AppColors.clipBlueLight)),
                          ),
                        Expanded(child: Text(item.isColorBackground ? 'Color Background' : item.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${TimeParser.formatStandard(item.startMs)} - ${TimeParser.formatStandard(item.endMs)} (${(item.durationMs / 1000).toStringAsFixed(1)}s)', style: const TextStyle(fontSize: 9.5, color: AppColors.textMuted, fontFamily: 'Consolas')),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close, size: 14, color: AppColors.textMuted), splashRadius: 14, onPressed: onRemove),
            ],
          ),
        ),
      ),
    );
  }
}
