import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/core/utils/time_parser.dart';
import 'package:frameflow/models/image_item.dart';
import 'package:frameflow/services/timing_engine.dart';

void main() {
  group('TimeParser Tests', () {
    test('Parses pure seconds string', () {
      expect(TimeParser.parseToMs('5'), equals(5000));
      expect(TimeParser.parseToMs('5.5'), equals(5500));
      expect(TimeParser.parseToMs('5,5'), equals(5500));
    });

    test('Parses MM:SS and MM:SS.mmm', () {
      expect(TimeParser.parseToMs('00:05'), equals(5000));
      expect(TimeParser.parseToMs('01:02'), equals(62000));
      expect(TimeParser.parseToMs('01:02.500'), equals(62500));
      expect(TimeParser.parseToMs('05:08'), equals(308000));
    });

    test('Parses HH:MM:SS', () {
      expect(TimeParser.parseToMs('01:00:00'), equals(3600000));
      expect(TimeParser.parseToMs('01:05:20.250'), equals(3920250));
    });

    test('Returns null for invalid input', () {
      expect(TimeParser.parseToMs(''), isNull);
      expect(TimeParser.parseToMs('abc'), isNull);
      expect(TimeParser.parseToMs('-5'), isNull);
    });

    test('Formats milliseconds to standard and detailed strings', () {
      expect(TimeParser.formatStandard(5000), equals('00:05'));
      expect(TimeParser.formatStandard(308000), equals('05:08'));
      expect(TimeParser.formatDetailed(5500), equals('00:05.500'));
      expect(TimeParser.formatSMPTE(5000, fps: 30), equals('00:00:05:00'));
    });
  });

  group('TimingEngine Tests', () {
    test('Calculates exact user design doc example (5 images)', () {
      final initialImages = [
        const ImageItem(id: '1', filePath: 'img1.jpg', displayName: 'Image 01', orderIndex: 0, userEndTimestampInput: '00:05'),
        const ImageItem(id: '2', filePath: 'img2.jpg', displayName: 'Image 02', orderIndex: 1, userEndTimestampInput: '00:07'),
        const ImageItem(id: '3', filePath: 'img3.jpg', displayName: 'Image 03', orderIndex: 2, userEndTimestampInput: '00:12'),
        const ImageItem(id: '4', filePath: 'img4.jpg', displayName: 'Image 04', orderIndex: 3, userEndTimestampInput: '00:18'),
        const ImageItem(id: '5', filePath: 'img5.jpg', displayName: 'Image 05', orderIndex: 4, userEndTimestampInput: '00:23'),
      ];

      final calculated = TimingEngine.calculateSequence(
        images: initialImages,
        snapFinalImageToAudio: false,
      );

      expect(calculated.length, equals(5));

      // Image 01: 00:00 -> 00:05 (duration 5s)
      expect(calculated[0].startMs, equals(0));
      expect(calculated[0].endMs, equals(5000));
      expect(calculated[0].durationMs, equals(5000));

      // Image 02: 00:05 -> 00:07 (duration 2s)
      expect(calculated[1].startMs, equals(5000));
      expect(calculated[1].endMs, equals(7000));
      expect(calculated[1].durationMs, equals(2000));

      // Image 03: 00:07 -> 00:12 (duration 5s)
      expect(calculated[2].startMs, equals(7000));
      expect(calculated[2].endMs, equals(12000));
      expect(calculated[2].durationMs, equals(5000));

      // Image 04: 00:12 -> 00:18 (duration 6s)
      expect(calculated[3].startMs, equals(12000));
      expect(calculated[3].endMs, equals(18000));
      expect(calculated[3].durationMs, equals(6000));

      // Image 05: 00:18 -> 00:23 (duration 5s)
      expect(calculated[4].startMs, equals(18000));
      expect(calculated[4].endMs, equals(23000));
      expect(calculated[4].durationMs, equals(5000));
    });

    test('Automatically extends final image to voice-over duration', () {
      // Voice-over is 05:08 = 308,000 ms
      const voiceOverMs = 308000;

      final images = [
        const ImageItem(id: '48', filePath: 'img48.jpg', displayName: 'Image 48', orderIndex: 0, userEndTimestampInput: '04:41'),
        const ImageItem(id: '49', filePath: 'img49.jpg', displayName: 'Image 49', orderIndex: 1, userEndTimestampInput: '04:49'),
        const ImageItem(id: '50', filePath: 'img50.jpg', displayName: 'Image 50', orderIndex: 2), // No timestamp entered
      ];

      final calculated = TimingEngine.calculateSequence(
        images: images,
        voiceOverDurationMs: voiceOverMs,
        snapFinalImageToAudio: true,
      );

      // Image 48: 00:00 -> 04:41 (281,000 ms)
      expect(calculated[0].endMs, equals(281000));

      // Image 49: 04:41 -> 04:49 (289,000 ms)
      expect(calculated[1].startMs, equals(281000));
      expect(calculated[1].endMs, equals(289000));

      // Image 50: 04:49 (289,000) -> 05:08 (308,000 ms)
      expect(calculated[2].startMs, equals(289000));
      expect(calculated[2].endMs, equals(308000));
      expect(calculated[2].durationMs, equals(19000)); // 19 seconds
    });

    test('Mid-sequence edit shifts subsequent image intervals', () {
      final initialImages = [
        const ImageItem(id: '1', filePath: 'img1.jpg', displayName: 'Image 01', orderIndex: 0, userEndTimestampInput: '00:05'),
        const ImageItem(id: '2', filePath: 'img2.jpg', displayName: 'Image 02', orderIndex: 1, userEndTimestampInput: '00:07'),
        const ImageItem(id: '3', filePath: 'img3.jpg', displayName: 'Image 03', orderIndex: 2, userEndTimestampInput: '00:12'),
      ];

      // Change Image 02 from 00:07 to 00:09
      final updated = TimingEngine.updateImageTimestamp(
        images: initialImages,
        imageId: '2',
        newTimestampInput: '00:09',
        snapFinalImageToAudio: false,
      );

      expect(updated[1].endMs, equals(9000));
      expect(updated[1].durationMs, equals(4000)); // 00:05 to 00:09 = 4s

      // Image 03 start time must now be 00:09
      expect(updated[2].startMs, equals(9000));
      expect(updated[2].endMs, equals(12000));
      expect(updated[2].durationMs, equals(3000)); // 00:09 to 00:12 = 3s
    });

    test('Bulk timestamp assignment correctly applies to 6 images', () {
      final images = List.generate(6, (i) => ImageItem(
        id: '$i',
        filePath: 'img_$i.jpg',
        displayName: 'Image $i',
        orderIndex: i,
      ));

      final bulkList = ['00:05', '00:07', '00:12', '00:18', '00:23', '00:31'];

      final calculated = TimingEngine.applyBulkTimestamps(
        images: images,
        timestampList: bulkList,
        snapFinalImageToAudio: false,
      );

      expect(calculated[0].endMs, equals(5000));
      expect(calculated[1].endMs, equals(7000));
      expect(calculated[2].endMs, equals(12000));
      expect(calculated[3].endMs, equals(18000));
      expect(calculated[4].endMs, equals(23000));
      expect(calculated[5].endMs, equals(31000));
    });

    test('Binary search finds active image index by playhead time', () {
      final images = [
        const ImageItem(id: '1', filePath: '1.jpg', displayName: '1', orderIndex: 0, startMs: 0, endMs: 5000),
        const ImageItem(id: '2', filePath: '2.jpg', displayName: '2', orderIndex: 1, startMs: 5000, endMs: 9000),
        const ImageItem(id: '3', filePath: '3.jpg', displayName: '3', orderIndex: 2, startMs: 9000, endMs: 15000),
      ];

      expect(TimingEngine.findActiveImageIndex(images, 0), equals(0));
      expect(TimingEngine.findActiveImageIndex(images, 2500), equals(0));
      expect(TimingEngine.findActiveImageIndex(images, 5000), equals(1));
      expect(TimingEngine.findActiveImageIndex(images, 8999), equals(1));
      expect(TimingEngine.findActiveImageIndex(images, 9000), equals(2));
      expect(TimingEngine.findActiveImageIndex(images, 14000), equals(2));
      expect(TimingEngine.findActiveImageIndex(images, 20000), equals(2)); // Caps at last
    });
  });
}
