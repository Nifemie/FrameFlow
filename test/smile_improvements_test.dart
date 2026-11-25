import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/models/image_item.dart';
import 'package:frameflow/models/timeline_track_item.dart';
import 'package:frameflow/providers/project_provider.dart';
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

      // Drag C (20s->25s) into the blank space starting at 5s
      final res = TimelineArrangementService.fillGapWithClip(
        images: images,
        clipId: 'c',
        startMs: 5000,
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
  });
}
