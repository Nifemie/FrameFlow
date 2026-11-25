import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/video_metadata_service.dart';

class FolderImageTile extends StatelessWidget {
  final int index;
  final String path;
  final String? timestamp;
  final bool isLast;
  final void Function(int from, int to) onMove;

  const FolderImageTile({
    super.key,
    required this.index,
    required this.path,
    this.timestamp,
    required this.isLast,
    required this.onMove,
  });

  Widget _buildMediaThumbnail() {
    if (AppConstants.isVideoFile(path)) {
      final thumb = VideoMetadataService.getCachedThumbnail(path);
      if (thumb != null && File(thumb).existsSync()) {
        return Image.file(File(thumb), cacheWidth: 150, fit: BoxFit.cover);
      }
      return Container(
        color: Colors.black54,
        child: const Center(
          child: Icon(Icons.videocam_rounded, size: 20, color: AppColors.accentOrange),
        ),
      );
    }
    return Image.file(
      File(path),
      cacheWidth: 150,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 16),
    );
  }

  Widget _buildContent({bool isGhost = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Opacity(
          opacity: isGhost ? 0.35 : 1.0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildMediaThumbnail(),
              Positioned(
                top: 2, left: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(3)),
                  child: Text('#${index + 1}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              if (timestamp != null)
                Positioned(
                  top: 2, right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(color: AppColors.exportGreen, borderRadius: BorderRadius.circular(3)),
                    child: Text(timestamp!, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.75),
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  child: Row(
                    children: [
                      if (index > 0)
                        InkWell(onTap: () => onMove(index, index - 1), child: const Icon(Icons.chevron_left, size: 11, color: Colors.white70)),
                      Expanded(
                        child: Text(p.basename(path), maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 7.5, color: Colors.white), textAlign: TextAlign.center,
                        ),
                      ),
                      if (!isLast)
                        InkWell(onTap: () => onMove(index, index + 1), child: const Icon(Icons.chevron_right, size: 11, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => onMove(d.data, index),
      builder: (context, candidate, _) {
        final isHovered = candidate.isNotEmpty;
        return MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Draggable<int>(
            data: index,
            feedback: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 75,
                height: 75,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: _buildMediaThumbnail(),
                ),
              ),
            ),
            childWhenDragging: _buildContent(isGhost: true),
            child: Container(
              decoration: BoxDecoration(
                border: isHovered ? Border.all(color: AppColors.exportGreen, width: 2) : null,
                borderRadius: BorderRadius.circular(4),
              ),
              child: _buildContent(),
            ),
          ),
        );
      },
    );
  }
}
