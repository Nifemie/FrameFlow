import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ShortcutConfig {
  final LogicalKeyboardKey playPauseKey;
  final LogicalKeyboardKey splitKey;
  final LogicalKeyboardKey stampKey;
  final LogicalKeyboardKey deleteKey;

  const ShortcutConfig({
    this.playPauseKey = LogicalKeyboardKey.space,
    this.splitKey = LogicalKeyboardKey.keyS,
    this.stampKey = LogicalKeyboardKey.keyM,
    this.deleteKey = LogicalKeyboardKey.delete,
  });

  ShortcutConfig copyWith({
    LogicalKeyboardKey? playPauseKey,
    LogicalKeyboardKey? splitKey,
    LogicalKeyboardKey? stampKey,
    LogicalKeyboardKey? deleteKey,
  }) {
    return ShortcutConfig(
      playPauseKey: playPauseKey ?? this.playPauseKey,
      splitKey: splitKey ?? this.splitKey,
      stampKey: stampKey ?? this.stampKey,
      deleteKey: deleteKey ?? this.deleteKey,
    );
  }

  String keyLabel(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.delete) return 'Delete';
    return key.keyLabel.toUpperCase();
  }
}

class ShortcutNotifier extends StateNotifier<ShortcutConfig> {
  ShortcutNotifier() : super(const ShortcutConfig());

  void setSplitKey(LogicalKeyboardKey key) => state = state.copyWith(splitKey: key);
  void setStampKey(LogicalKeyboardKey key) => state = state.copyWith(stampKey: key);
  void setPlayPauseKey(LogicalKeyboardKey key) => state = state.copyWith(playPauseKey: key);
  void setDeleteKey(LogicalKeyboardKey key) => state = state.copyWith(deleteKey: key);
  void resetDefaults() => state = const ShortcutConfig();
}

final shortcutProvider = StateNotifierProvider<ShortcutNotifier, ShortcutConfig>((ref) => ShortcutNotifier());
