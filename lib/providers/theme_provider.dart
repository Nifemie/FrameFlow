import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudioIconDef {
  final String id;
  final String label;
  final String group;
  final IconData icon;
  final Color defaultColor;

  const StudioIconDef({
    required this.id,
    required this.label,
    required this.group,
    required this.icon,
    required this.defaultColor,
  });
}

class StudioIconCatalog {
  static const List<StudioIconDef> all = [
    // Top Bar
    StudioIconDef(id: 'newProject', label: 'New Project', group: 'Top Bar', icon: Icons.note_add_outlined, defaultColor: Color(0xFFF3F4F6)),
    StudioIconDef(id: 'openProject', label: 'Open Project', group: 'Top Bar', icon: Icons.folder_open_outlined, defaultColor: Color(0xFFF3F4F6)),
    StudioIconDef(id: 'saveProject', label: 'Save Project', group: 'Top Bar', icon: Icons.save_outlined, defaultColor: Color(0xFFF3F4F6)),
    StudioIconDef(id: 'undo', label: 'Undo', group: 'Top Bar', icon: Icons.undo, defaultColor: Color(0xFFF3F4F6)),
    StudioIconDef(id: 'redo', label: 'Redo', group: 'Top Bar', icon: Icons.redo, defaultColor: Color(0xFFF3F4F6)),
    StudioIconDef(id: 'timingMode', label: 'Timing Mode', group: 'Top Bar', icon: Icons.bolt, defaultColor: Color(0xFFFF6600)),
    StudioIconDef(id: 'workspaceFocus', label: 'Workspace Focus', group: 'Top Bar', icon: Icons.grid_view_rounded, defaultColor: Color(0xFF9CA3AF)),
    StudioIconDef(id: 'themeCustomize', label: 'Customize Theme', group: 'Top Bar', icon: Icons.palette_outlined, defaultColor: Color(0xFFFF6600)),
    StudioIconDef(id: 'shortcuts', label: 'Keyboard Shortcuts', group: 'Top Bar', icon: Icons.keyboard_outlined, defaultColor: Color(0xFF9CA3AF)),
    StudioIconDef(id: 'exportVideo', label: 'Export Video', group: 'Top Bar', icon: Icons.file_upload_outlined, defaultColor: Color(0xFFFFFFFF)),

    // Left Panel
    StudioIconDef(id: 'importVoiceOver', label: 'Import Voice-Over', group: 'Left Panel', icon: Icons.audio_file_outlined, defaultColor: Color(0xFFFF6600)),
    StudioIconDef(id: 'addColorMatte', label: 'Add Color Matte', group: 'Left Panel', icon: Icons.palette_outlined, defaultColor: Colors.purpleAccent),
    StudioIconDef(id: 'bulkTimestamps', label: 'Bulk Timestamps', group: 'Left Panel', icon: Icons.playlist_add_check, defaultColor: Color(0xFFFF6600)),
    StudioIconDef(id: 'importFolder', label: 'Import Folder', group: 'Left Panel', icon: Icons.folder_open, defaultColor: Color(0xFFFF6600)),
    StudioIconDef(id: 'addMedia', label: 'Add Media', group: 'Left Panel', icon: Icons.add_photo_alternate, defaultColor: Color(0xFFFFFFFF)),

    // Viewport Controls
    StudioIconDef(id: 'prevCut', label: 'Previous Cut', group: 'Viewport Controls', icon: Icons.skip_previous, defaultColor: Color(0xFFF3F4F6)),
    StudioIconDef(id: 'playPause', label: 'Play / Pause', group: 'Viewport Controls', icon: Icons.play_arrow, defaultColor: Color(0xFFFFFFFF)),
    StudioIconDef(id: 'nextCut', label: 'Next Cut', group: 'Viewport Controls', icon: Icons.skip_next, defaultColor: Color(0xFFF3F4F6)),
    StudioIconDef(id: 'stampCut', label: 'Stamp Cut (M)', group: 'Viewport Controls', icon: Icons.bookmark_add, defaultColor: Color(0xFFFF6600)),
    StudioIconDef(id: 'splitClip', label: 'Split Clip (S)', group: 'Viewport Controls', icon: Icons.content_cut, defaultColor: Color(0xFFFF6600)),
    StudioIconDef(id: 'aspectRatio', label: 'Aspect Ratio', group: 'Viewport Controls', icon: Icons.aspect_ratio, defaultColor: Color(0xFF9CA3AF)),

    // Timeline & Tracks
    StudioIconDef(id: 'timelineHeader', label: 'Timeline Header', group: 'Timeline & Tracks', icon: Icons.view_timeline_rounded, defaultColor: Color(0xFFFF6600)),
    StudioIconDef(id: 'snapToggle', label: 'Snap Toggle', group: 'Timeline & Tracks', icon: Icons.vertical_align_center, defaultColor: Color(0xFFFF6600)),
    StudioIconDef(id: 'markK', label: 'Mark (K)', group: 'Timeline & Tracks', icon: Icons.bookmark_add_outlined, defaultColor: Colors.amber),
    StudioIconDef(id: 'packLeft', label: 'Pack Left', group: 'Timeline & Tracks', icon: Icons.format_align_left, defaultColor: Colors.cyanAccent),
    StudioIconDef(id: 'zoomOutIn', label: 'Zoom Out / In', group: 'Timeline & Tracks', icon: Icons.zoom_in, defaultColor: Color(0xFF9CA3AF)),
    StudioIconDef(id: 'zoomFit', label: 'Zoom Fit', group: 'Timeline & Tracks', icon: Icons.fit_screen_rounded, defaultColor: Color(0xFFFF6600)),
    StudioIconDef(id: 'randomiseAnim', label: 'Randomise Animations', group: 'Timeline & Tracks', icon: Icons.auto_awesome, defaultColor: Color(0xFFFF6600)),
    StudioIconDef(id: 'addTrack', label: 'Add Track', group: 'Timeline & Tracks', icon: Icons.add, defaultColor: Color(0xFFFF6600)),
    StudioIconDef(id: 'trackVisibility', label: 'Track Visibility (Eye)', group: 'Timeline & Tracks', icon: Icons.visibility, defaultColor: Color(0xFFF3F4F6)),
    StudioIconDef(id: 'trackMute', label: 'Track Mute', group: 'Timeline & Tracks', icon: Icons.volume_up, defaultColor: Color(0xFFF3F4F6)),
    StudioIconDef(id: 'trackTimestamp', label: 'Track Timestamps', group: 'Timeline & Tracks', icon: Icons.access_time, defaultColor: Color(0xFFFF6600)),
    StudioIconDef(id: 'trackAddBg', label: 'Track Add Background', group: 'Timeline & Tracks', icon: Icons.palette_outlined, defaultColor: Colors.purpleAccent),
    StudioIconDef(id: 'trackAddMedia', label: 'Track Add Media', group: 'Timeline & Tracks', icon: Icons.add_photo_alternate_outlined, defaultColor: Color(0xFF60A5FA)),
    StudioIconDef(id: 'trackDelete', label: 'Track Delete', group: 'Timeline & Tracks', icon: Icons.delete_outline, defaultColor: Color(0xFFEF4444)),
  ];
}

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
  final Map<String, Color> iconColors;

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
    this.iconColors = const {},
  });

  Color iconColor(String id, Color fallback) => iconColors[id] ?? fallback;

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
    iconColors: {},
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
    iconColors: {},
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
    Map<String, Color>? iconColors,
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
      iconColors: iconColors ?? this.iconColors,
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
        'iconColors': iconColors.map((k, v) => MapEntry(k, v.toARGB32())),
      };

  factory StudioThemeColors.fromMap(Map<String, dynamic> map) {
    Color c(String key, Color fallback) {
      final v = map[key];
      return v is int ? Color(v) : fallback;
    }

    final rawIcons = map['iconColors'] as Map<String, dynamic>? ?? const {};
    final parsedIcons = <String, Color>{};
    for (final e in rawIcons.entries) {
      if (e.value is int) {
        parsedIcons[e.key] = Color(e.value as int);
      }
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
      iconColors: parsedIcons,
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

  void updateIconColor(String iconId, Color color) {
    final next = Map<String, Color>.from(state.iconColors);
    next[iconId] = color;
    state = state.copyWith(presetName: 'custom', iconColors: next);
    _save();
  }

  void resetIconColors() {
    state = state.copyWith(presetName: 'custom', iconColors: const {});
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
