import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/image_item.dart';
import '../../../models/project.dart';

class PreviewCanvas extends StatelessWidget {
  final ImageItem? activeImage;
  final VideoAspectRatio aspectRatio;

  const PreviewCanvas({
    super.key,
    required this.activeImage,
    required this.aspectRatio,
  });

  Widget _buildImageContent(ImageItem item) {
    final imageFile = File(item.filePath);

    switch (item.fitMode) {
      case ImageFitMode.fit:
        return Center(
          child: Image.file(
            imageFile,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _buildErrorPlaceholder(),
          ),
        );

      case ImageFitMode.fill:
        return Image.file(
          imageFile,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => _buildErrorPlaceholder(),
        );

      case ImageFitMode.blurredBackground:
        return Stack(
          fit: StackFit.expand,
          children: [
            // Blurred background layer
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Image.file(
                imageFile,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            Container(color: Colors.black.withValues(alpha: 0.3)),
            // Foreground sharp image
            Center(
              child: Image.file(
                imageFile,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => _buildErrorPlaceholder(),
              ),
            ),
          ],
        );

      case ImageFitMode.center:
        return Center(
          child: Image.file(
            imageFile,
            fit: BoxFit.none,
            errorBuilder: (_, _, _) => _buildErrorPlaceholder(),
          ),
        );
    }
  }

  Widget _buildErrorPlaceholder() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image, size: 48, color: AppColors.errorRed),
          SizedBox(height: 8),
          Text('Image file not found', style: TextStyle(color: AppColors.textMuted)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio.ratioValue,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.surfaceBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: activeImage != null
              ? _buildImageContent(activeImage!)
              : const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.movie_creation_outlined,
                          size: 48, color: AppColors.textMuted),
                      SizedBox(height: 8),
                      Text(
                        'Preview Stage',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted),
                      ),
                      Text(
                        'Add images and voice-over to begin',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
