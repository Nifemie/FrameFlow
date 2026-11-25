import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/models/image_item.dart';
import 'package:frameflow/models/timeline_track_item.dart';
import 'package:frameflow/providers/project_provider.dart';

void main() {
  group('Color Background & Multi-Track Tests', () {
    test('ImageItem correctly identifies solid color background and converts color', () {
      const colorBg = ImageItem(
        id: 'bg1', filePath: 'color_background', displayName: 'Color BG',
        orderIndex: 0, durationMs: 4000, backgroundColorValue: 0xFF4F46E5,
      );

      expect(colorBg.isColorBackground, isTrue);
      expect(colorBg.backgroundColor, const Color(0xFF4F46E5));
      expect(colorBg.durationMs, 4000);

      const normalImg = ImageItem(id: 'img1', filePath: 'pic.jpg', displayName: 'pic.jpg', orderIndex: 1);
      expect(normalImg.isColorBackground, isFalse);
      expect(normalImg.backgroundColor, isNull);
    });

    test('ProjectNotifier adds Color Background clip and updates its color dynamically', () {
      final container = ProviderContainer();
      final notifier = container.read(projectProvider.notifier);

      notifier.addColorBackground(color: const Color(0xFFFF0055), durationMs: 5000);
      var project = container.read(projectProvider);
      expect(project.images.length, 1);
      expect(project.images.first.isColorBackground, isTrue);
      expect(project.images.first.backgroundColor, const Color(0xFFFF0055));
      expect(project.images.first.durationMs, 5000);

      // Update color live
      notifier.updateImageColor(project.images.first.id, const Color(0xFF00FFCC));
      project = container.read(projectProvider);
      expect(project.images.first.backgroundColor, const Color(0xFF00FFCC));
    });

    test('Project tracks support Eye visibility toggle and Mute toggle', () {
      final container = ProviderContainer();
      final notifier = container.read(projectProvider.notifier);

      var project = container.read(projectProvider);
      expect(project.effectiveTracks.length, 1);
      expect(project.isTrackVisible('track_v1'), isTrue);
      expect(project.isAudioMuted, isFalse);

      // Toggle media track visibility (Eye icon)
      notifier.toggleTrackVisibility('track_v1');
      project = container.read(projectProvider);
      expect(project.isTrackVisible('track_v1'), isFalse);

      // Add audio track and toggle audio mute (Mute icon)
      notifier.addTrack(name: 'Audio Track', type: TrackType.audio);
      final audioTrack = container.read(projectProvider).effectiveTracks.firstWhere((t) => t.type == TrackType.audio);
      notifier.toggleTrackMute(audioTrack.id);
      project = container.read(projectProvider);
      expect(project.isAudioMuted, isTrue);
    });

    test('ProjectNotifier adds new overlay/underlay tracks dynamically', () {
      final container = ProviderContainer();
      final notifier = container.read(projectProvider.notifier);

      notifier.addTrack(name: 'V2 (Overlay)', type: TrackType.overlayVideo);
      final project = container.read(projectProvider);
      expect(project.effectiveTracks.length, 2);
      expect(project.effectiveTracks.first.name, 'V2 (Overlay)');
      expect(project.effectiveTracks.first.type, TrackType.overlayVideo);
      expect(project.effectiveTracks.first.isVisible, isTrue);
    });

    test('Multi-track timeline segregates V1 and Underlay clips independently', () {
      final container = ProviderContainer();
      final notifier = container.read(projectProvider.notifier);

      // Add clip to V1
      notifier.addImages(['v1_clip1.png', 'v1_clip2.png'], trackId: 'track_v1');
      // Add background to BG Underlay
      notifier.addColorBackground(color: const Color(0xFF112233), durationMs: 10000, trackId: 'track_bg');

      final project = container.read(projectProvider);
      final v1Clips = project.imagesForTrack('track_v1');
      final bgClips = project.imagesForTrack('track_bg');

      expect(v1Clips.length, 2);
      expect(bgClips.length, 1);
      expect(v1Clips[0].trackId, 'track_v1');
      expect(bgClips[0].trackId, 'track_bg');
      expect(bgClips[0].isColorBackground, isTrue);
      expect(bgClips[0].durationMs, 10000);

      // Verify V1 and BG start from 0 independently
      expect(v1Clips[0].startMs, 0);
      expect(bgClips[0].startMs, 0);
    });

    test('TimelineArrangementService allows moving background clip start time freely', () {
      final container = ProviderContainer();
      final notifier = container.read(projectProvider.notifier);

      notifier.addColorBackground(color: const Color(0xFF112233), durationMs: 10000, trackId: 'track_bg');
      var project = container.read(projectProvider);
      final bgId = project.imagesForTrack('track_bg').first.id;
      expect(project.imagesForTrack('track_bg').first.startMs, 0);

      // Freely move background start time to 24000ms
      notifier.moveImageClipStart(bgId, 24000);
      project = container.read(projectProvider);
      expect(project.imagesForTrack('track_bg').first.startMs, 24000);
      expect(project.imagesForTrack('track_bg').first.endMs, 34000);
    });

    test('TimelineArrangementService swaps clips on drag and drop and preserves exact durations', () {
      final container = ProviderContainer();
      final notifier = container.read(projectProvider.notifier);

      notifier.addImages(['clipA.png', 'clipB.png']);
      // Set unequal durations and explicit start timestamps: clipA = 5000ms, clipB = 2600ms
      notifier.trimClipEnd(container.read(projectProvider).images[0].id, 5000);
      notifier.trimClipEnd(container.read(projectProvider).images[1].id, 7600);
      notifier.updateStartTimestamp(container.read(projectProvider).images[1].id, '00:05.00');

      var project = container.read(projectProvider);
      final idA = project.images[0].id;
      final idB = project.images[1].id;
      expect(project.images[0].durationMs, 5000);
      expect(project.images[1].durationMs, 2600);

      notifier.swapImageClips(idA, idB);
      project = container.read(projectProvider);
      expect(project.images[0].displayName, 'clipB.png');
      expect(project.images[0].durationMs, 2600);
      expect(project.images[0].startMs, 0);
      expect(project.images[0].endMs, 2600);

      expect(project.images[1].displayName, 'clipA.png');
      expect(project.images[1].durationMs, 5000);
      expect(project.images[1].startMs, 2600);
      expect(project.images[1].endMs, 7600);
    });

    test('reorderAndOccupy inserts front/back while strictly preserving duration', () {
      final container = ProviderContainer();
      final notifier = container.read(projectProvider.notifier);

      notifier.addImages(['clip1.png', 'clip2.png', 'clip3.png']);
      final p1 = container.read(projectProvider);
      final id1 = p1.images[0].id;
      final id3 = p1.images[2].id;

      // Drag clip3 to front of clip1
      notifier.reorderAndOccupy(id3, id1, insertBefore: true);
      final p2 = container.read(projectProvider);
      expect(p2.images[0].id, id3);
      expect(p2.images[1].id, id1);
      expect(p2.images[0].startMs, 0);
      expect(p2.images[0].durationMs, 5000);
      expect(p2.images[1].startMs, 5000);
    });

    test('TimelineArrangementService fills blank gaps with image or color matte', () {
      final container = ProviderContainer();
      final notifier = container.read(projectProvider.notifier);

      notifier.fillBlankGap(startMs: 24000, endMs: 28500, trackId: 'track_v1', isColorBg: true);
      final project = container.read(projectProvider);
      expect(project.images.length, 1);
      expect(project.images.first.startMs, 24000);
      expect(project.images.first.endMs, 28500);
      expect(project.images.first.isColorBackground, isTrue);
    });
  });
}
