import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/features/timestamps/services/csv_service.dart';
import 'package:frameflow/models/image_item.dart';
import 'package:frameflow/services/timing_engine.dart';

void main() {
  group('Option 1 Timeline Gap Scenario Tests', () {
    test('Media 01 (00:00-00:04), Media 02 (00:04-00:06), Media 03 (00:10-00:14) gap 00:06-00:10', () {
      final initial = [
        const ImageItem(id: '1', filePath: '1.jpg', displayName: '01 Media', orderIndex: 0, userEndTimestampInput: '00:04'),
        const ImageItem(id: '2', filePath: '2.jpg', displayName: '02 Media', orderIndex: 1, userEndTimestampInput: '00:06'),
        const ImageItem(id: '3', filePath: '3.jpg', displayName: '03 Media', orderIndex: 2, userStartTimestampInput: '00:10', userEndTimestampInput: '00:14'),
      ];

      final calculated = TimingEngine.calculateSequence(images: initial, snapFinalImageToAudio: false);

      expect(calculated[0].startMs, equals(0));
      expect(calculated[0].endMs, equals(4000));
      expect(calculated[1].startMs, equals(4000));
      expect(calculated[1].endMs, equals(6000));

      expect(calculated[2].startMs, equals(10000));
      expect(calculated[2].endMs, equals(14000));

      // Gap between 00:06 and 00:10 should return -1 for active clip (renders blank/black screen)
      expect(TimingEngine.findActiveImageIndex(calculated, 7000), equals(-1));
      expect(TimingEngine.findActiveImageIndex(calculated, 9000), equals(-1));
      expect(TimingEngine.findActiveImageIndex(calculated, 10000), equals(2));
    });

    test('Bulk timestamp list with range (e.g. 00:10 - 00:15) leaves blank gap', () {
      final images = [
        const ImageItem(id: '1', filePath: '1.jpg', displayName: 'Img 1', orderIndex: 0),
        const ImageItem(id: '2', filePath: '2.jpg', displayName: 'Img 2', orderIndex: 1),
        const ImageItem(id: '3', filePath: '3.jpg', displayName: 'Img 3', orderIndex: 2),
      ];

      final stamps = ['00:03', '00:04', '00:10 - 00:15'];
      final calculated = TimingEngine.applyBulkTimestamps(
        images: images,
        timestampList: stamps,
        snapFinalImageToAudio: false,
      );

      expect(calculated[0].startMs, equals(0));
      expect(calculated[0].endMs, equals(3000));
      expect(calculated[1].startMs, equals(3000));
      expect(calculated[1].endMs, equals(4000));

      // Image 3 has intentional blank screen gap from 00:04 to 00:10
      expect(calculated[2].startMs, equals(10000));
      expect(calculated[2].endMs, equals(15000));
      expect(calculated[2].durationMs, equals(5000));

      // Active clip index inside the gap is -1 (blank screen)
      expect(TimingEngine.findActiveImageIndex(calculated, 5000), equals(-1));
      expect(TimingEngine.findActiveImageIndex(calculated, 10000), equals(2));
    });

    test('CsvService parses both single timestamps and range timestamps', () {
      const raw = '00:03\n00:04\n00:10 - 00:15\n00:19';
      final parsed = CsvService.parseTimestampsFromText(raw);

      expect(parsed.length, equals(4));
      expect(parsed[0], equals('00:03'));
      expect(parsed[1], equals('00:04'));
      expect(parsed[2], equals('00:10 - 00:15'));
      expect(parsed[3], equals('00:19'));
    });
  });
}
