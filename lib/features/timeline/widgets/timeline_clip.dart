import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/image_item.dart';

class TimelineClip extends StatelessWidget {
  final ImageItem item;
  final bool isSelected;
  final double zoomScale;
  final VoidCallback onTap;

  const TimelineClip({
    super.key,
    required this.item,
    required this.isSelected,
    required this.zoomScale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Width proportional to duration and timeline zoom slider
    final baseWidth = (item.durationMs / 1000) * 40 * zoomScale;
    final width = baseWidth.clamp(75.0, 600.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 70,
        margin: const EdgeInsets.only(right: 3),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? Colors.white : AppColors.clipBlue,
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.clipBlue.withValues(alpha: 0.5),
                blurRadius: 6,
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image Thumbnail
            Opacity(
              opacity: 0.55,
              child: Image.file(
                File(item.filePath),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.surfaceBorder,
                  child: const Icon(Icons.image, size: 20, color: AppColors.textMuted),
                ),
              ),
            ),

            // Top gradient overlay for text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),

            // Clip labels
            Padding(
              padding: const EdgeInsets.all(5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title + Order badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.clipBlue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          '#${item.orderIndex + 1}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Duration text
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        '${(item.durationMs / 1000).toStringAsFixed(1)}s',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
