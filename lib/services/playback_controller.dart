import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../providers/project_provider.dart';
import '../providers/selection_provider.dart';

class PlaybackController {
  final Ref _ref;
  final AudioPlayer _player = AudioPlayer();
  Timer? _timer;
  String? _loadedAudioPath;

  PlaybackController(this._ref) {
    // Listen to native audio playback position updates
    _player.positionStream.listen((duration) {
      if (_ref.read(isPlayingProvider)) {
        _ref.read(playheadPositionProvider.notifier).state = duration.inMilliseconds;
      }
    });

    // Listen to player state changes
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        pause();
        _ref.read(playheadPositionProvider.notifier).state = 0;
      }
    });
  }

  Future<void> togglePlayPause() async {
    final isPlaying = _ref.read(isPlayingProvider);
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> play() async {
    final project = _ref.read(projectProvider);
    final currentMs = _ref.read(playheadPositionProvider);
    final totalMs = project.totalDurationMs;

    if (totalMs <= 0) return;

    // If playhead is at the end, restart from beginning
    final startMs = currentMs >= totalMs ? 0 : currentMs;
    _ref.read(playheadPositionProvider.notifier).state = startMs;
    _ref.read(isPlayingProvider.notifier).state = true;

    if (project.voiceOver != null) {
      // Audio-driven playback
      try {
        if (_loadedAudioPath != project.voiceOver!.filePath) {
          await _player.setFilePath(project.voiceOver!.filePath);
          _loadedAudioPath = project.voiceOver!.filePath;
        }
        await _player.seek(Duration(milliseconds: startMs));
        await _player.play();
      } catch (e) {
        // Fallback to timer playback if audio playback fails
        _startTimer(startMs, totalMs);
      }
    } else {
      // Software clock playback (when no audio is imported)
      _startTimer(startMs, totalMs);
    }
  }

  void _startTimer(int initialMs, int maxMs) {
    _timer?.cancel();
    int current = initialMs;
    const interval = Duration(milliseconds: 33); // ~30 fps tick

    _timer = Timer.periodic(interval, (timer) {
      current += 33;
      if (current >= maxMs) {
        pause();
        _ref.read(playheadPositionProvider.notifier).state = 0;
      } else {
        _ref.read(playheadPositionProvider.notifier).state = current;
      }
    });
  }

  Future<void> pause() async {
    _timer?.cancel();
    _timer = null;
    await _player.pause();
    _ref.read(isPlayingProvider.notifier).state = false;
  }

  Future<void> seek(int targetMs) async {
    final project = _ref.read(projectProvider);
    final clamped = targetMs.clamp(0, project.totalDurationMs);
    _ref.read(playheadPositionProvider.notifier).state = clamped;

    if (project.voiceOver != null && _loadedAudioPath == project.voiceOver!.filePath) {
      await _player.seek(Duration(milliseconds: clamped));
    }
  }

  void stepNext() {
    final project = _ref.read(projectProvider);
    final currentMs = _ref.read(playheadPositionProvider);
    for (int i = 0; i < project.images.length; i++) {
      if (project.images[i].startMs > currentMs + 100) {
        seek(project.images[i].startMs);
        _ref.read(selectedImageIdProvider.notifier).state = project.images[i].id;
        return;
      }
    }
  }

  void stepPrevious() {
    final project = _ref.read(projectProvider);
    final currentMs = _ref.read(playheadPositionProvider);
    for (int i = project.images.length - 1; i >= 0; i--) {
      if (project.images[i].startMs < currentMs - 200) {
        seek(project.images[i].startMs);
        _ref.read(selectedImageIdProvider.notifier).state = project.images[i].id;
        return;
      }
    }
    seek(0);
  }

  void dispose() {
    _timer?.cancel();
    _player.dispose();
  }
}

final playbackControllerProvider = Provider<PlaybackController>((ref) {
  final controller = PlaybackController(ref);
  ref.onDispose(() => controller.dispose());
  return controller;
});
