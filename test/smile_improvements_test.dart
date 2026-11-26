import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/models/image_item.dart';
import 'package:frameflow/models/timeline_track_item.dart';
import 'package:frameflow/models/voice_over.dart';
import 'package:frameflow/providers/project_provider.dart';
import 'package:frameflow/services/clip_editing_service.dart';
import 'package:frameflow/services/timeline_arrangement_service.dart';

void main() {
  group('Smile-Branch Improvements Tests', () {
    test('Video source range cuts 5min-8min out of 10min video into 3min clip', () {
      final notifier = ProjectNotifier();
      notifier.addImages([r'C:\videos\sample.mp4']);
      final clip = notifier.state.images.first;
      // Simulate 10 min source duration
      notifier.state = notifier.state.copyWith(
        images: [clip.copyWith(sourceDurationMs: 600000)],
      );

      // Select 5:00 (300000ms) to 8:00 (480000ms) -> 3:00 (180000ms)
      notifier.updateVideoSourceRange(clip.id, 300000, 480000);
      final updated = notifier.state.images.first;

      expect(updated.sourceStartOffsetMs, equals(300000));
      expect(updated.durationMs, equals(180000));
      expect(updated.endMs - updated.startMs, equals(180000));
    });

    test('Dragging image over blank space places it inside gap without pushing gap further', () {
      final images = [
        const ImageItem(id: 'a', filePath: 'a.jpg', displayName: 'A', orderIndex: 0, startMs: 0, endMs: 5000, durationMs: 5000, userStartTimestampInput: '0.00', userEndTimestampInput: '5.00'),
        // Blank space from 5s to 15s (10s)
        const ImageItem(id: 'b', filePath: 'b.jpg', displayName: 'B', orderIndex: 1, startMs: 15000, endMs: 20000, durationMs: 5000, userStartTimestampInput: '15.00', userEndTimestampInput: '20.00'),
        const ImageItem(id: 'c', filePath: 'c.jpg', displayName: 'C', orderIndex: 2, startMs: 20000, endMs: 25000, durationMs: 5000, userStartTimestampInput: '20.00', userEndTimestampInput: '25.00'),
      ];

      // Drag C (20s->25s) into the blank space starting at 5s..15s
      final res = TimelineArrangementService.fillGapWithClip(
        images: images,
        clipId: 'c',
        startMs: 5000,
        gapEndMs: 15000,
        targetTrackId: 'track_v1',
      );

      final a = res.firstWhere((i) => i.id == 'a');
      final c = res.firstWhere((i) => i.id == 'c');
      final b = res.firstWhere((i) => i.id == 'b');

      expect(a.startMs, equals(0));
      expect(a.endMs, equals(5000));
      expect(c.startMs, equals(5000));
      expect(c.endMs, equals(10000));
      // B stays at 15s (not pushed further!)
      expect(b.startMs, equals(15000));
      expect(b.endMs, equals(20000));
    });

    test('Dragging larger clip into smaller blank gap fits without pushing next clip', () {
      final images = [
        const ImageItem(id: 'a', filePath: 'a.jpg', displayName: 'A', orderIndex: 0, startMs: 0, endMs: 5000, durationMs: 5000, userStartTimestampInput: '0.00', userEndTimestampInput: '5.00'),
        // Blank space from 5s to 9.4s (4.4s)
        const ImageItem(id: 'b', filePath: 'b.jpg', displayName: 'B', orderIndex: 1, startMs: 9400, endMs: 14400, durationMs: 5000, userStartTimestampInput: '9.40', userEndTimestampInput: '14.40'),
        const ImageItem(id: 'c', filePath: 'c.jpg', displayName: 'C', orderIndex: 2, startMs: 14400, endMs: 19400, durationMs: 5000, userStartTimestampInput: '14.40', userEndTimestampInput: '19.40'),
      ];

      final res = TimelineArrangementService.fillGapWithClip(
        images: images,
        clipId: 'c',
        startMs: 5000,
        gapEndMs: 9400,
        targetTrackId: 'track_v1',
      );

      final c = res.firstWhere((i) => i.id == 'c');
      final b = res.firstWhere((i) => i.id == 'b');
      expect(c.startMs, equals(5000));
      expect(c.endMs, equals(9400));
      expect(b.startMs, equals(9400));
      expect(b.endMs, equals(14400));
    });

    test('Auto-rearrange from left packs clips sequentially from 00:00', () {
      final images = [
        const ImageItem(id: 'a', filePath: 'a.jpg', displayName: 'A', orderIndex: 0, startMs: 0, endMs: 5000, durationMs: 5000),
        const ImageItem(id: 'b', filePath: 'b.jpg', displayName: 'B', orderIndex: 1, startMs: 15000, endMs: 20000, durationMs: 5000),
      ];

      final packed = TimelineArrangementService.autoArrangeFromLeft(images: images);
      expect(packed[0].startMs, equals(0));
      expect(packed[0].endMs, equals(5000));
      expect(packed[1].startMs, equals(5000));
      expect(packed[1].endMs, equals(10000));
    });

    test('Snapping snaps to nearest target when enabled and skips when disabled', () {
      final (snappedOn, lineOn) = TimelineArrangementService.snapToTargets(
        targetMs: 5120,
        targets: [0, 5000, 10000],
        pxPerSec: 40.0,
        enabled: true,
        thresholdPx: 12.0, // 300ms at 40px/s
      );
      expect(snappedOn, equals(5000));
      expect(lineOn, equals(5000));

      final (snappedOff, lineOff) = TimelineArrangementService.snapToTargets(
        targetMs: 5120,
        targets: [0, 5000, 10000],
        pxPerSec: 40.0,
        enabled: false,
      );
      expect(snappedOff, equals(5120));
      expect(lineOff, isNull);
    });

    test('Timeline markers & asset marking toggle and undo work', () {
      final notifier = ProjectNotifier();
      notifier.addImages(['a.jpg']);
      final id = notifier.state.images.first.id;

      notifier.toggleAssetMark(id);
      expect(notifier.state.images.first.isMarked, isTrue);

      notifier.addMarker(4500, label: 'Hook');
      expect(notifier.state.markers.length, equals(1));
      expect(notifier.state.markers.first.label, equals('Hook'));

      // Undo removes marker
      expect(notifier.undo(), isTrue);
      expect(notifier.state.markers, isEmpty);
      expect(notifier.state.images.first.isMarked, isTrue);

      // Undo unmarks asset
      expect(notifier.undo(), isTrue);
      expect(notifier.state.images.first.isMarked, isFalse);
    });

    test('Auto-delete empty secondary track when its last clip is deleted', () {
      final notifier = ProjectNotifier();
      notifier.addTrack(name: 'V2 (Overlay)', type: TrackType.overlayVideo);
      final overlayTrack = notifier.state.tracks.firstWhere((t) => t.type == TrackType.overlayVideo);
      notifier.addImages(['overlay.png'], trackId: overlayTrack.id);
      final overlayClipId = notifier.state.images.first.id;

      notifier.removeImage(overlayClipId);
      expect(notifier.state.tracks.any((t) => t.id == overlayTrack.id), isFalse);
    });

    test('Extending clip right into blank gap reduces only the blank gap, overflow pushes next clip', () {
      final images = [
        const ImageItem(id: 'a', filePath: 'a.jpg', displayName: 'A', orderIndex: 0, startMs: 0, endMs: 5000, durationMs: 5000, userStartTimestampInput: '0.00', userEndTimestampInput: '5.00'),
        // 5s blank from 5s..10s
        const ImageItem(id: 'b', filePath: 'b.jpg', displayName: 'B', orderIndex: 1, startMs: 10000, endMs: 15000, durationMs: 5000, userStartTimestampInput: '10.00', userEndTimestampInput: '15.00'),
      ];

      // 1. Extend A from 5s to 7s (partially into 5s..10s blank) -> B stays at 10s..15s!
      final partial = ClipEditingService.rippleTrimClipEnd(
        images: images,
        clipId: 'a',
        newEndMs: 7000,
      );
      expect(partial[0].startMs, equals(0));
      expect(partial[0].endMs, equals(7000));
      expect(partial[1].startMs, equals(10000));
      expect(partial[1].endMs, equals(15000));

      // 2. Extend A from 5s to 12s (fully covers 5s..10s blank + 2s overflow) -> B pushed by +2s to 12s..17s!
      final overflow = ClipEditingService.rippleTrimClipEnd(
        images: images,
        clipId: 'a',
        newEndMs: 12000,
      );
      expect(overflow[0].startMs, equals(0));
      expect(overflow[0].endMs, equals(12000));
      expect(overflow[1].startMs, equals(12000));
      expect(overflow[1].endMs, equals(17000));
    });

    test('Extending clip left into blank gap reduces only the blank gap', () {
      final images = [
        const ImageItem(id: 'a', filePath: 'a.jpg', displayName: 'A', orderIndex: 0, startMs: 0, endMs: 5000, durationMs: 5000, userStartTimestampInput: '0.00', userEndTimestampInput: '5.00'),
        // 5s blank from 5s..10s
        const ImageItem(id: 'b', filePath: 'b.jpg', displayName: 'B', orderIndex: 1, startMs: 10000, endMs: 15000, durationMs: 5000, userStartTimestampInput: '10.00', userEndTimestampInput: '15.00'),
      ];

      final res = ClipEditingService.trimClipStart(
        images: images,
        clipId: 'b',
        newStartMs: 7000,
      );
      expect(res[0].startMs, equals(0));
      expect(res[0].endMs, equals(5000));
      expect(res[1].startMs, equals(7000));
      expect(res[1].endMs, equals(15000));
    });

    test('Adding an asset with insertAtMs inserts at playhead instead of end', () {
      final notifier = ProjectNotifier();
      notifier.addImages(['a.jpg'], insertAtMs: 0); // 0..5000ms
      // Playhead is at 10000ms (10s) on track_v1 -> leaves 5s..10s blank and places b.jpg at 10s..15s
      notifier.addImages(['b.jpg'], insertAtMs: 10000);
      expect(notifier.state.images.length, equals(2));
      expect(notifier.state.images[0].startMs, equals(0));
      expect(notifier.state.images[0].endMs, equals(5000));
      expect(notifier.state.images[1].startMs, equals(10000));
      expect(notifier.state.images[1].endMs, equals(15000));

      // Playhead is at 5000ms (inside 5s..10s blank) -> places c.jpg at 5s..10s
      notifier.addImages(['c.jpg'], insertAtMs: 5000);
      expect(notifier.state.images.length, equals(3));
      expect(notifier.state.images[1].displayName, equals('c.jpg'));
      expect(notifier.state.images[1].startMs, equals(5000));
      expect(notifier.state.images[1].endMs, equals(10000));
      expect(notifier.state.images[2].displayName, equals('b.jpg'));
      expect(notifier.state.images[2].startMs, equals(10000));
    });

    test('Dragging clip to new Assets track keeps exact position & duration even with voice-over', () {
      final notifier = ProjectNotifier();
      notifier.setVoiceOver(const VoiceOver(filePath: 'vo.mp3', fileName: 'vo.mp3', durationMs: 60000));
      notifier.addImages(['img1.jpg'], insertAtMs: 0); // 5s clip on track_v1
      notifier.addTrack(name: 'Assets', type: TrackType.overlayVideo);
      final assetsTrack = notifier.state.tracks.firstWhere((t) => t.type == TrackType.overlayVideo);
      final clip = notifier.state.images.first;

      notifier.placeClipOnTrack(clip: clip, targetTrackId: assetsTrack.id, startMs: 12000);
      final onAssets = notifier.state.imagesForTrack(assetsTrack.id);

      expect(onAssets.length, equals(1));
      expect(onAssets.first.startMs, equals(12000));
      expect(onAssets.first.durationMs, equals(5000));
      expect(onAssets.first.endMs, equals(17000));
    });
  });
}
