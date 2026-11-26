import 'package:flutter/material.dart';
import '../../providers/theme_provider.dart';

/// Professional dark palette inspired by DaVinci Resolve, Premiere Pro & CapCut desktop.
/// Deep black & dark charcoal with vibrant orange highlights.
class AppColors {
  // Base Deep Black & Dark Charcoal Surfaces
  static const Color background = Color(0xFF0C0D11);
  static const Color surface = Color(0xFF13151C);
  static const Color cardSurface = Color(0xFF181B24);
  static const Color surfaceLight = Color(0xFF202430);
  static const Color surfaceBorder = Color(0xFF282D3C);
  static const Color surfaceBorderSubtle = Color(0xFF1C202B);
  static const Color surfaceBorderHover = Color(0xFF3E4559);

  // Vibrant Orange Primary Accent & Playhead
  static const Color accentOrange = Color(0xFFFF6600);
  static const Color accentOrangeHover = Color(0xFFFF7A1A);
  static const Color playheadNeedle = Color(0xFFFF6600);
  static const Color selectionOutline = Color(0xFFFF6600);
  static const Color activeTool = Color(0xFFFF6600);

  // Secondary Accents & Status
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color warningYellow = Color(0xFFEAB308);
  static const Color exportGreen = Color(0xFF10B981);
  static const Color exportGreenHover = Color(0xFF34D399);
  static const Color errorRed = Color(0xFFEF4444);

  // Clips & Waveforms (Deep charcoal base with clean colored rims)
  static const Color clipDefault = Color(0xFF1E232F);
  static const Color clipBlue = Color(0xFF2563EB);
  static const Color clipBlueLight = Color(0xFF60A5FA);
  static const Color waveform = Color(0xFFFF6600);

  // Marquee Selection Box
  static const Color selectionBox = Color(0x33FF6600);
  static const Color selectionBoxBorder = Color(0xFFFF6600);

  // Typography
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
}

class AppTheme {
  static ThemeData get darkTheme => fromStudioColors(StudioThemeColors.defaultTheme);

  static ThemeData fromStudioColors(StudioThemeColors colors) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.viewportColor,
      cardColor: colors.leftPanelColor,
      dividerColor: AppColors.surfaceBorder,
      colorScheme: ColorScheme.dark(
        primary: colors.buttonColor,
        secondary: colors.buttonColor,
        surface: colors.leftPanelColor,
        error: AppColors.errorRed,
      ),
      fontFamily: 'Segoe UI',
      iconTheme: IconThemeData(color: colors.textColor),
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: colors.textColor, fontSize: 13),
        bodySmall: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        titleMedium: TextStyle(color: colors.textColor, fontWeight: FontWeight.w600, fontSize: 14),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.surfaceBorder),
        trackColor: WidgetStateProperty.all(colors.timelineColor),
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(3),
      ),
    );
  }
}
