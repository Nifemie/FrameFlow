import 'package:flutter/material.dart';

/// Professional dark palette inspired by Movavi / CapCut desktop editors.
class AppColors {
  // Base Surfaces
  static const Color background = Color(0xFF161922);
  static const Color surface = Color(0xFF1E222D);
  static const Color surfaceLight = Color(0xFF282E3E);
  static const Color surfaceBorder = Color(0xFF333A4D);

  // Playhead & Accents
  static const Color accentOrange = Color(0xFFFF5C36);
  static const Color playheadNeedle = Color(0xFFFF5C36);

  // Clips & Waveforms
  static const Color clipBlue = Color(0xFF3D7BFD);
  static const Color clipBlueLight = Color(0xFF5D93FF);
  static const Color waveform = Color(0xFF4A89FF);

  // Status & Actions
  static const Color exportGreen = Color(0xFF27AE60);
  static const Color exportGreenHover = Color(0xFF2ECC71);
  static const Color errorRed = Color(0xFFE74C3C);
  static const Color textPrimary = Color(0xFFECEFF4);
  static const Color textSecondary = Color(0xFF9AA0A6);
  static const Color textMuted = Color(0xFF6B7280);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.surface,
      dividerColor: AppColors.surfaceBorder,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.clipBlue,
        secondary: AppColors.accentOrange,
        surface: AppColors.surface,
        error: AppColors.errorRed,
      ),
      fontFamily: 'Segoe UI',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 13),
        bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 11),
        titleMedium: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.surfaceBorder),
        trackColor: WidgetStateProperty.all(AppColors.background),
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(3),
      ),
    );
  }
}
