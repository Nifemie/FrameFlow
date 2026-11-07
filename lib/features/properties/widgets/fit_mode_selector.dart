import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/image_item.dart';

class FitModeSelector extends StatelessWidget {
  final ImageFitMode currentMode;
  final ValueChanged<ImageFitMode> onModeChanged;

  const FitModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  Widget _buildModeButton({
    required ImageFitMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = (currentMode == mode);

    return InkWell(
      onTap: () => onModeChanged(mode),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.clipBlue.withValues(alpha: 0.2) : AppColors.background,
          border: Border.all(
            color: isSelected ? AppColors.clipBlue : AppColors.surfaceBorder,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.clipBlueLight : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Image Fit Mode',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        _buildModeButton(
          mode: ImageFitMode.fit,
          icon: Icons.fit_screen_outlined,
          label: 'Fit (Letterbox)',
        ),
        const SizedBox(height: 6),
        _buildModeButton(
          mode: ImageFitMode.fill,
          icon: Icons.crop_free_outlined,
          label: 'Fill & Crop',
        ),
        const SizedBox(height: 6),
        _buildModeButton(
          mode: ImageFitMode.blurredBackground,
          icon: Icons.blur_on_outlined,
          label: 'Blurred Background',
        ),
        const SizedBox(height: 6),
        _buildModeButton(
          mode: ImageFitMode.center,
          icon: Icons.center_focus_strong_outlined,
          label: 'Center (Original)',
        ),
      ],
    );
  }
}
