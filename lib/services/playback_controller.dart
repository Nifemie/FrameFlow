import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../models/audio_clip_item.dart';
import '../models/image_item.dart';
import '../models/project.dart';
import '../providers/project_provider.dart';
import '../providers/selection_provider.dart';
import 'audio_editing_service.dart';
import 'video_playback_engine.dart';

class PlaybackController {
  final Ref _ref;
  final AudioPlayer _player = AudioPlayer();
  Timer? _timer;
  String? _loadedAudioPath;
  DateTime _lastAudioSeek = DateTime.now();
  AudioClipItem? _activeClip;
  bool _isTransitioning = false;
  DateTime? _lastClockTick;
  DateTime _lastVideoDriftSync = DateTime.now();

  PlaybackController(this._ref) {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && _ref.read(isPlayingProvider) && !_isTransitioning && _activeClip != null) {
        _handleClipTransition();
      }
    });
    _ref.listen<List<AudioClipItem>>(projectProvider.select((p) => p.effectiveAudioClips), (_, next) => _syncAudioStateWithProject(next));
    _ref.listen<bool>(projectProvider.select((p) => p.isAudioMuted), (_, muted) {
      if (muted) {
        _player.setVolume(0.0);
      } else if (_activeClip != null) {
        _player.setVolume(_activeClip!.volume.clamp(0.0, 1.0));
      }
    });
  }

  void stopAudioIfActive(String clipId) {
    if (_activeClip?.id == clipId) {
      _activeClip = null;
      try { _player.pause(); } catch (_) {}
    }
  }

  ImageItem? _findActiveVideoClip(Project project, int timelineMs) {
    for (final img in project.images) {
      if (img.isVideo && img.startMs <= timelineMs && timelineMs < img.endMs) {
        return img;
      }
    }
    return null;
  }

  void _syncAudioStateWithProject(List<AudioClipItem> currentClips) {
    if (currentClips.isEmpty || (_activeClip != null && !currentClips.any((c) => c.id == _activeClip!.id))) {
      _activeClip = null;
      try { _player.pause(); } catch (_) {}
      final curMs = _ref.read(playheadPositionProvider);
      final newClip = AudioEditingService.findClipAt(currentClips, curMs);
      if (newClip != null && _ref.read(isPlayingProvider)) _playClipAt(newClip, curMs);
    }
  }

  void scrub(int targetMs) {
    if (_ref.read(isPlayingProvider)) pause();
    final total = _ref.read(projectProvider).totalDurationMs;
    final clamped = targetMs.clamp(0, total);
    _ref.read(playheadPositionProvider.notifier).state = clamped;
    _syncVideoAudioSeek(clamped, false);
  }

  void setLiveVolume(double volume) {
    try { _player.setVolume(volume.clamp(0.0, 1.0)); } catch (_) {}
  }

  Future<void> _playClipAt(AudioClipItem clip, int timelineMs) async {
    _activeClip = clip;
    final fileOffsetMs = clip.fileStartOffsetMs + (timelineMs - clip.startTimelineMs);
    try {
      if (_loadedAudioPath != clip.filePath) await _player.setFilePath(_loadedAudioPath = clip.filePath);
      final muted = _ref.read(projectProvider).isAudioMuted;
      await _player.setVolume(muted ? 0.0 : clip.volume.clamp(0.0, 1.0));
      await _player.seek(Duration(milliseconds: fileOffsetMs));
      await _player.play();
    } catch (_) {
      _activeClip = null;
    }
  }

  Future<void> _handleClipTransition() async {
    if (_isTransitioning) return;
    _isTransitioning = true;
    try {
      final project = _ref.read(projectProvider);
      final int endMs = _activeClip != null ? _activeClip!.endTimelineMs : _ref.read(playheadPositionProvider);
      _activeClip = null;
      if (endMs >= project.totalDurationMs - 100) {
        await pause();
        _ref.read(playheadPositionProvider.notifier).state = 0;
        return;
      }
      _ref.read(playheadPositionProvider.notifier).state = endMs;
      AudioClipItem? nextClip;
      for (final c in project.effectiveAudioClips) {
        if (c.startTimelineMs >= endMs) { nextClip = c; break; }
      }
      if (nextClip != null && nextClip.startTimelineMs <= endMs + 50) {
        await _playClipAt(nextClip, nextClip.startTimelineMs);
      } else {
        try { await _player.pause(); await _player.seek(Duration.zero); } catch (_) {}
      }
    } finally {
      _isTransitioning = false;
    }
  }

  void _startClock() {
    _timer?.cancel();
    _lastClockTick = DateTime.now();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
      if (!_ref.read(isPlayingProvider) || _isTransitioning) return;
      final now = DateTime.now();
      final elapsed = _lastClockTick != null ? now.difference(_lastClockTick!).inMilliseconds : 50;
      _lastClockTick = now;
      final project = _ref.read(projectProvider);
      final totalMs = project.totalDurationMs;

      int cur;
      if (_activeClip != null) {
        // Voice-over / music track drives the timeline
        final audioPos = _player.position.inMilliseconds;
        final offsetInClip = audioPos - _activeClip!.fileStartOffsetMs;
        if (offsetInClip >= _activeClip!.durationMs) { await _handleClipTransition(); return; }
        cur = (_activeClip!.startTimelineMs + offsetInClip).clamp(0, totalMs);
        _ref.read(playheadPositionProvider.notifier).state = cur;

        // Keep video in sync with audio clock
        final activeVid = _findActiveVideoClip(project, cur);
        if (activeVid != null) {
          final fileOffset = _calculateVideoSourceOffset(activeVid, cur);
          if (VideoPlaybackEngine.currentClipId != activeVid.id) {
            final isVideoMuted = !project.isTrackVisible(activeVid.trackId) || project.isTrackMuted(activeVid.trackId) || activeVid.isMuted;
            await VideoPlaybackEngine.playVideo(activeVid, fileOffset, isMuted: isVideoMuted);
          } else {
            final vidOffset = VideoPlaybackEngine.positionMs;
            if ((vidOffset - fileOffset).abs() > 800 && now.difference(_lastVideoDriftSync).inMilliseconds > 2000) {
              _lastVideoDriftSync = now;
              await VideoPlaybackEngine.seekVideo(fileOffset);
            }
          }
        } else {
          await VideoPlaybackEngine.pauseVideo();
        }
      } else {
        // No voice-over audio track: Software timeline clock drives the playback
        final prevPlayhead = _ref.read(playheadPositionProvider);
        cur = prevPlayhead + elapsed;
        if (cur >= totalMs) {
          await pause();
          _ref.read(playheadPositionProvider.notifier).state = 0;
          return;
        }
        _ref.read(playheadPositionProvider.notifier).state = cur;

        final nextClip = AudioEditingService.findClipAt(project.effectiveAudioClips, cur);
        if (nextClip != null) await _playClipAt(nextClip, cur);

        // Keep hardware video engine synchronized with the timeline clock
        final activeVid = _findActiveVideoClip(project, cur);
        if (activeVid != null) {
          final isVideoMuted = !project.isTrackVisible(activeVid.trackId) || project.isTrackMuted(activeVid.trackId) || activeVid.isMuted;
          final expectedOffset = _calculateVideoSourceOffset(activeVid, cur);

          if (VideoPlaybackEngine.currentClipId != activeVid.id) {
            // Smoothly transition to new video clip
            await VideoPlaybackEngine.playVideo(activeVid, expectedOffset, isMuted: isVideoMuted);
          } else if (!VideoPlaybackEngine.isPlaying && !VideoPlaybackEngine.isOpening) {
            await VideoPlaybackEngine.playVideo(activeVid, expectedOffset, isMuted: isVideoMuted);
          } else if (VideoPlaybackEngine.isPlaying) {
            final vidOffset = VideoPlaybackEngine.positionMs;
            if ((vidOffset - expectedOffset).abs() > 600 &&
                now.difference(_lastVideoDriftSync).inMilliseconds > 1500) {
              _lastVideoDriftSync = now;
              await VideoPlaybackEngine.seekVideo(expectedOffset);
            }
          }
        } else {
          if (VideoPlaybackEngine.isPlaying) {
            await VideoPlaybackEngine.pauseVideo();
          }
        }
      }
    });
  }

  Future<void> togglePlayPause() async => _ref.read(isPlayingProvider) ? await pause() : await play();

  Future<void> play() async {
    final project = _ref.read(projectProvider);
    if (project.totalDurationMs <= 0) return;
    final cur = _ref.read(playheadPositionProvider);
    final startMs = cur >= project.totalDurationMs ? 0 : cur;
    _ref.read(playheadPositionProvider.notifier).state = startMs;
    _ref.read(isPlayingProvider.notifier).state = true;

    // Start audio track clip (voice-over / music)
    final clip = AudioEditingService.findClipAt(project.effectiveAudioClips, startMs);
    if (clip != null) await _playClipAt(clip, startMs);

    // Start hardware-accelerated video playback
    final video = _findActiveVideoClip(project, startMs);
    if (video != null) {
      final isTrackHidden = !project.isTrackVisible(video.trackId);
      final offsetMs = _calculateVideoSourceOffset(video, startMs);
      await VideoPlaybackEngine.playVideo(video, offsetMs, isMuted: isTrackHidden);
    }

    _startClock();
  }

  Future<void> pause() async {
    _timer?.cancel();
    _timer = null;
    _isTransitioning = false;
    try { await _player.pause(); } catch (_) {}
    await VideoPlaybackEngine.pauseVideo();
    _ref.read(isPlayingProvider.notifier).state = false;
  }

  Future<void> _syncVideoAudioSeek(int clamped, bool isPlaying) async {
    final project = _ref.read(projectProvider);
    final video = _findActiveVideoClip(project, clamped);
    if (video != null) {
      final isVideoMuted = !project.isTrackVisible(video.trackId) || project.isTrackMuted(video.trackId) || video.isMuted;
      final offsetMs = _calculateVideoSourceOffset(video, clamped);
      if (isPlaying) {
        await VideoPlaybackEngine.playVideo(video, offsetMs, isMuted: isVideoMuted);
      } else {
        await VideoPlaybackEngine.prepareVideo(video, offsetMs);
      }
    } else {
      await VideoPlaybackEngine.pauseVideo();
    }
  }

  int _calculateVideoSourceOffset(ImageItem video, int playheadMs) {
    final offsetInClip = (playheadMs - video.startMs).clamp(0, video.durationMs);
    final fileOffset = video.sourceStartOffsetMs + offsetInClip;
    if (video.sourceDurationMs != null && video.sourceDurationMs! > 0) {
      return fileOffset.clamp(0, video.sourceDurationMs!);
    }
    return fileOffset;
  }

  Future<void> seek(int targetMs, {bool syncAudioImmediately = false}) async {
    final project = _ref.read(projectProvider);
    final clamped = targetMs.clamp(0, project.totalDurationMs);
    _ref.read(playheadPositionProvider.notifier).state = clamped;
    final isPlaying = _ref.read(isPlayingProvider);
    final clip = AudioEditingService.findClipAt(project.effectiveAudioClips, clamped);

    if (clip != null) {
      if (isPlaying) {
        await _playClipAt(clip, clamped);
      } else {
        final now = DateTime.now();
        if (syncAudioImmediately || now.difference(_lastAudioSeek).inMilliseconds > 75) {
          _lastAudioSeek = now;
          try {
            if (_loadedAudioPath != clip.filePath) await _player.setFilePath(_loadedAudioPath = clip.filePath);
            await _player.seek(Duration(milliseconds: clip.fileStartOffsetMs + (clamped - clip.startTimelineMs)));
          } catch (_) {}
        }
      }
    } else {
      _activeClip = null;
      try { await _player.pause(); await _player.seek(Duration.zero); } catch (_) {}
    }

    await _syncVideoAudioSeek(clamped, isPlaying);
  }

  void stepNext() {
    final p = _ref.read(projectProvider), cur = _ref.read(playheadPositionProvider);
    for (final img in p.images) {
      if (img.startMs > cur + 100) {
        seek(img.startMs, syncAudioImmediately: true);
        ref.read(selectedImageIdProvider.notifier).state = img.id;
        return;
      }
    }
  }

  void stepPrevious() {
    final p = _ref.read(projectProvider), cur = _ref.read(playheadPositionProvider);
    for (int i = p.images.length - 1; i >= 0; i--) {
      if (p.images[i].startMs < cur - 200) {
        seek(p.images[i].startMs, syncAudioImmediately: true);
        ref.read(selectedImageIdProvider.notifier).state = p.images[i].id;
        return;
      }
    }
    seek(0, syncAudioImmediately: true);
  }

  Ref get ref => _ref;

  void dispose() {
    _timer?.cancel();
    _player.dispose();
    VideoPlaybackEngine.dispose();
  }
}

final playbackControllerProvider = Provider<PlaybackController>((ref) {
  final controller = PlaybackController(ref);
  ref.onDispose(() => controller.dispose());
  return controller;
});
