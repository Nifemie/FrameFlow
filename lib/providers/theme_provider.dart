import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudioThemeColors {
  final String presetName; // 'default', 'black', 'custom'
  final Color topPanelColor;
  final Color leftPanelColor;
  final Color rightPanelColor;
  final Color viewportColor;
  final Color viewportControlsColor;
  final Color timelineColor;
  final Color textColor;
  final Color buttonColor;
  final Color playheadColor;
  final Color exportColor;

  const StudioThemeColors({
    required this.presetName,
    required this.topPanelColor,
    required this.leftPanelColor,
    required this.rightPanelColor,
    required this.viewportColor,
    required this.viewportControlsColor,
    required this.timelineColor,
    required this.textColor,
    required this.buttonColor,
    required this.playheadColor,
    required this.exportColor,
  });

  static const StudioThemeColors defaultTheme = StudioThemeColors(
    presetName: 'default',
    topPanelColor: Color(0xFF13151C),
    leftPanelColor: Color(0xFF13151C),
    rightPanelColor: Color(0xFF13151C),
    viewportColor: Color(0xFF0C0D11),
    viewportControlsColor: Color(0xFF13151C),
    timelineColor: Color(0xFF0C0D11),
    textColor: Color(0xFFF3F4F6),
    buttonColor: Color(0xFFFF6600),
    playheadColor: Color(0xFFFF6600),
    exportColor: Color(0xFF10B981),
  );

  static const StudioThemeColors blackTheme = StudioThemeColors(
    presetName: 'black',
    topPanelColor: Color(0xFF050505),
    leftPanelColor: Color(0xFF050505),
    rightPanelColor: Color(0xFF050505),
    viewportColor: Color(0xFF000000),
    viewportControlsColor: Color(0xFF050505),
    timelineColor: Color(0xFF000000),
    textColor: Color(0xFFFFFFFF),
    buttonColor: Color(0xFFFF6600),
    playheadColor: Color(0xFFFF6600),
    exportColor: Color(0xFF10B981),
  );

  StudioThemeColors copyWith({
    String? presetName,
    Color? topPanelColor,
    Color? leftPanelColor,
    Color? rightPanelColor,
    Color? viewportColor,
    Color? viewportControlsColor,
    Color? timelineColor,
    Color? textColor,
    Color? buttonColor,
    Color? playheadColor,
    Color? exportColor,
  }) {
    return StudioThemeColors(
      presetName: presetName ?? this.presetName,
      topPanelColor: topPanelColor ?? this.topPanelColor,
      leftPanelColor: leftPanelColor ?? this.leftPanelColor,
      rightPanelColor: rightPanelColor ?? this.rightPanelColor,
      viewportColor: viewportColor ?? this.viewportColor,
      viewportControlsColor: viewportControlsColor ?? this.viewportControlsColor,
      timelineColor: timelineColor ?? this.timelineColor,
      textColor: textColor ?? this.textColor,
      buttonColor: buttonColor ?? this.buttonColor,
      playheadColor: playheadColor ?? this.playheadColor,
      exportColor: exportColor ?? this.exportColor,
    );
  }

  Map<String, dynamic> toMap() => {
        'presetName': presetName,
        'topPanelColor': topPanelColor.toARGB32(),
        'leftPanelColor': leftPanelColor.toARGB32(),
        'rightPanelColor': rightPanelColor.toARGB32(),
        'viewportColor': viewportColor.toARGB32(),
        'viewportControlsColor': viewportControlsColor.toARGB32(),
        'timelineColor': timelineColor.toARGB32(),
        'textColor': textColor.toARGB32(),
        'buttonColor': buttonColor.toARGB32(),
        'playheadColor': playheadColor.toARGB32(),
        'exportColor': exportColor.toARGB32(),
      };

  factory StudioThemeColors.fromMap(Map<String, dynamic> map) {
    Color c(String key, Color fallback) {
      final v = map[key];
      return v is int ? Color(v) : fallback;
    }

    return StudioThemeColors(
      presetName: map['presetName'] as String? ?? 'default',
      topPanelColor: c('topPanelColor', defaultTheme.topPanelColor),
      leftPanelColor: c('leftPanelColor', defaultTheme.leftPanelColor),
      rightPanelColor: c('rightPanelColor', defaultTheme.rightPanelColor),
      viewportColor: c('viewportColor', defaultTheme.viewportColor),
      viewportControlsColor: c('viewportControlsColor', defaultTheme.viewportControlsColor),
      timelineColor: c('timelineColor', defaultTheme.timelineColor),
      textColor: c('textColor', defaultTheme.textColor),
      buttonColor: c('buttonColor', defaultTheme.buttonColor),
      playheadColor: c('playheadColor', defaultTheme.playheadColor),
      exportColor: c('exportColor', defaultTheme.exportColor),
    );
  }
}

class SavedCustomTheme {
  final String id;
  final String name;
  final StudioThemeColors colors;

  const SavedCustomTheme({
    required this.id,
    required this.name,
    required this.colors,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'colors': colors.toMap(),
      };

  factory SavedCustomTheme.fromMap(Map<String, dynamic> map) {
    return SavedCustomTheme(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Custom Theme',
      colors: StudioThemeColors.fromMap(map['colors'] as Map<String, dynamic>? ?? const {}),
    );
  }
}

class ThemeNotifier extends StateNotifier<StudioThemeColors> {
  static const _prefsKey = 'frameflow_studio_theme_v1';

  ThemeNotifier() : super(StudioThemeColors.defaultTheme) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        state = StudioThemeColors.fromMap(decoded);
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(state.toMap()));
    } catch (_) {}
  }

  void applyDefaultTheme() {
    state = StudioThemeColors.defaultTheme;
    _save();
  }

  void applyBlackTheme() {
    state = StudioThemeColors.blackTheme;
    _save();
  }

  void applySavedTheme(SavedCustomTheme saved) {
    state = saved.colors.copyWith(presetName: 'saved:${saved.id}');
    _save();
  }

  void updateColor(String key, Color color) {
    switch (key) {
      case 'topPanel':
        state = state.copyWith(presetName: 'custom', topPanelColor: color);
        break;
      case 'leftPanel':
        state = state.copyWith(presetName: 'custom', leftPanelColor: color);
        break;
      case 'rightPanel':
        state = state.copyWith(presetName: 'custom', rightPanelColor: color);
        break;
      case 'viewport':
        state = state.copyWith(presetName: 'custom', viewportColor: color);
        break;
      case 'viewportControls':
        state = state.copyWith(presetName: 'custom', viewportControlsColor: color);
        break;
      case 'timeline':
        state = state.copyWith(presetName: 'custom', timelineColor: color);
        break;
      case 'text':
        state = state.copyWith(presetName: 'custom', textColor: color);
        break;
      case 'button':
        state = state.copyWith(presetName: 'custom', buttonColor: color);
        break;
      case 'playhead':
        state = state.copyWith(presetName: 'custom', playheadColor: color);
        break;
      case 'export':
        state = state.copyWith(presetName: 'custom', exportColor: color);
        break;
    }
    _save();
  }
}

class SavedThemesNotifier extends StateNotifier<List<SavedCustomTheme>> {
  static const _prefsKey = 'frameflow_saved_custom_themes_v1';

  SavedThemesNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        state = list.map((e) => SavedCustomTheme.fromMap(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(state.map((t) => t.toMap()).toList()));
    } catch (_) {}
  }

  SavedCustomTheme saveTheme(String name, StudioThemeColors colors) {
    final trimmed = name.trim();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final item = SavedCustomTheme(
      id: id,
      name: trimmed.isEmpty ? 'Custom ${state.length + 1}' : trimmed,
      colors: colors.copyWith(presetName: 'saved:$id'),
    );
    state = [...state, item];
    _save();
    return item;
  }

  void deleteTheme(String id) {
    state = state.where((t) => t.id != id).toList();
    _save();
  }
}

class RecommendedColorsNotifier extends StateNotifier<List<Color>> {
  static const _prefsKey = 'frameflow_recommended_colors_v1';

  static const List<Color> defaultRecommended = [
    Color(0xFFFF6600), // Studio Orange
    Color(0xFF10B981), // Emerald Green
    Color(0xFF3B82F6), // Electric Blue
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Rose Pink
    Color(0xFFEF4444), // Crimson Red
    Color(0xFFEAB308), // Amber Gold
    Color(0xFF000000), // Pure Black
    Color(0xFF13151C), // Studio Charcoal
    Color(0xFFF3F4F6), // Crisp White
  ];

  RecommendedColorsNotifier() : super(defaultRecommended) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        state = list.whereType<int>().map((v) => Color(v)).toList();
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(state.map((c) => c.toARGB32()).toList()));
    } catch (_) {}
  }

  void addColor(Color color) {
    if (state.any((c) => c.toARGB32() == color.toARGB32())) return;
    state = [...state, color];
    _save();
  }

  void removeColor(Color color) {
    state = state.where((c) => c.toARGB32() != color.toARGB32()).toList();
    _save();
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, StudioThemeColors>((ref) {
  return ThemeNotifier();
});

final savedThemesProvider = StateNotifierProvider<SavedThemesNotifier, List<SavedCustomTheme>>((ref) {
  return SavedThemesNotifier();
});

final recommendedColorsProvider = StateNotifierProvider<RecommendedColorsNotifier, List<Color>>((ref) {
  return RecommendedColorsNotifier();
});
