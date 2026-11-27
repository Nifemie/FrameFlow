import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/models/audio_clip_item.dart';
import 'package:frameflow/models/image_item.dart';
import 'package:frameflow/models/project.dart';
import 'package:frameflow/models/text_overlay_item.dart';
import 'package:frameflow/providers/export_range_provider.dart';
import 'package:frameflow/services/project_slice_service.dart';

void main() {
  group('Selective / Range-Based Export Tests', () {
    test('ExportRangeNotifier sets, clamps, and clears In/Out points and saved ranges', () {
      final notifier = ExportRangeNotifier();
      expect(notifier.state.hasRange, isFalse);

      notifier.setInPoint(2000, totalDurationMs: 20000);
      notifier.setOutPoint(8000, totalDurationMs: 20000);
      expect(notifier.state.hasRange, isTrue);
      expect(notifier.state.activeRange!.startMs, equals(2000));
      expect(notifier.state.activeRange!.endMs, equals(8000));
      expect(notifier.state.activeRange!.durationMs, equals(6000));

      notifier.addRange(notifier.state.activeRange!);
      expect(notifier.state.savedRanges.length, equals(1));

      notifier.clearRange();
      expect(notifier.state.hasRange, isFalse);
      expect(notifier.state.savedRanges.length, equals(1));

      notifier.removeSavedRange(0);
      expect(notifier.state.savedRanges, isEmpty);
    });

    test('ProjectSliceService slices clips, video source offsets, audio, and text overlays accurately', () {
      final project = Project(
        id: 'p1',
        name: 'Range Test',
        images: [
          const ImageItem(
            id: 'c1',
            filePath: 'a.jpg',
            displayName: 'A',
            orderIndex: 0,
            startMs: 0,
            endMs: 5000,
            durationMs: 5000,
          ),
          const ImageItem(
            id: 'v1',
            filePath: 'v.mp4',
            displayName: 'V',
            orderIndex: 1,
            startMs: 5000,
            endMs: 15000,
            durationMs: 10000,
            sourceStartOffsetMs: 1000,
          ),
          const ImageItem(
            id: 'c2',
            filePath: 'b.jpg',
            displayName: 'B',
            orderIndex: 2,
            startMs: 15000,
            endMs: 20000,
            durationMs: 5000,
          ),
        ],
        audioClips: const [
          AudioClipItem(
            id: 'a1',
            filePath: 'vo.mp3',
            fileName: 'vo.mp3',
            startTimelineMs: 2000,
            durationMs: 16000,
            fileStartOffsetMs: 500,
            orderIndex: 0,
          ),
        ],
        textOverlays: const [
          TextOverlayItem(
            id: 't1',
            text: 'Title',
            startMs: 4000,
            durationMs: 6000,
          ),
        ],
      );

      // Slice [3000ms .. 12000ms] (9s total)
      final sliced = ProjectSliceService.sliceProject(project, 3000, 12000);

      // Visual clips: c1 (3000..5000 -> 0..2000), v1 (5000..12000 -> 2000..9000); c2 excluded
      expect(sliced.images.length, equals(2));
      expect(sliced.images[0].id, equals('c1'));
      expect(sliced.images[0].startMs, equals(0));
      expect(sliced.images[0].endMs, equals(2000));
      expect(sliced.images[0].durationMs, equals(2000));

      expect(sliced.images[1].id, equals('v1'));
      expect(sliced.images[1].startMs, equals(2000));
      expect(sliced.images[1].endMs, equals(9000));
      expect(sliced.images[1].durationMs, equals(7000));
      expect(sliced.images[1].sourceStartOffsetMs, equals(1000));

      // Audio clip: 2000..18000 intersected with 3000..12000 -> 0..9000, fileStartOffset += 1000 -> 1500
      expect(sliced.audioClips.length, equals(1));
      expect(sliced.audioClips.first.startTimelineMs, equals(0));
      expect(sliced.audioClips.first.durationMs, equals(9000));
      expect(sliced.audioClips.first.fileStartOffsetMs, equals(1500));

      // Text overlay: 4000..10000 intersected with 3000..12000 -> 1000..7000 (duration 6000)
      expect(sliced.textOverlays.length, equals(1));
      expect(sliced.textOverlays.first.startMs, equals(1000));
      expect(sliced.textOverlays.first.durationMs, equals(6000));
    });
  });
}
