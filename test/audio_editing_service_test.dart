import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/models/audio_clip_item.dart';
import 'package:frameflow/services/audio_editing_service.dart';

void main() {
  group('AudioEditingService Tests', () {
    test('Appends second audio clip starting exactly where first ends', () {
      final initial = [
        const AudioClipItem(id: '1', filePath: 'song1.mp3', fileName: 'Song 1', startTimelineMs: 0, durationMs: 72000, orderIndex: 0),
      ];

      final updated = AudioEditingService.appendAudioClip(
        existingClips: initial, filePath: 'song2.mp3', fileName: 'Song 2', durationMs: 60000,
      );

      expect(updated.length, equals(2));
      expect(updated[1].startTimelineMs, equals(72000));
      expect(updated[1].durationMs, equals(60000));
      expect(updated[1].endTimelineMs, equals(132000));
    });

    test('Appends audio clip with custom start timeline position (gap / silence)', () {
      final initial = [
        const AudioClipItem(id: '1', filePath: 'song1.mp3', fileName: 'Song 1', startTimelineMs: 0, durationMs: 15000, orderIndex: 0),
      ];

      // User places next audio at 27000ms (vertical bar playhead) leaving 12s gap
      final updated = AudioEditingService.appendAudioClip(
        existingClips: initial, filePath: 'song2.mp3', fileName: 'Song 2', durationMs: 20000, customStartMs: 27000,
      );

      expect(updated.length, equals(2));
      expect(updated[0].endTimelineMs, equals(15000));
      expect(updated[1].startTimelineMs, equals(27000));
      expect(updated[1].startTimelineMs - updated[0].endTimelineMs, equals(12000)); // 12 second gap!
    });

    test('Moves audio clip start time freely to reposition along timeline', () {
      final clips = [
        const AudioClipItem(id: '1', filePath: 'song.mp3', fileName: 'Song', startTimelineMs: 5000, durationMs: 20000, orderIndex: 0),
      ];

      final moved = AudioEditingService.moveClipStart(clips: clips, clipId: '1', newStartMs: 14000);
      expect(moved.first.startTimelineMs, equals(14000));
      expect(moved.first.endTimelineMs, equals(34000));
    });

    test('Splits audio clip at playhead position', () {
      final clips = [
        const AudioClipItem(id: '1', filePath: 'song.mp3', fileName: 'Song', startTimelineMs: 0, durationMs: 60000, orderIndex: 0),
      ];

      final split = AudioEditingService.splitAudioClipAt(clips: clips, playheadMs: 25000);
      expect(split, isNotNull);
      expect(split!.length, equals(2));
      expect(split[0].durationMs, equals(25000));
      expect(split[1].startTimelineMs, equals(25000));
      expect(split[1].fileStartOffsetMs, equals(25000));
      expect(split[1].durationMs, equals(35000));
    });

    test('Updates volume for specific audio clip within safe bounds', () {
      final clips = [
        const AudioClipItem(id: '1', filePath: 'a.mp3', fileName: 'A', startTimelineMs: 0, durationMs: 10000, orderIndex: 0),
        const AudioClipItem(id: '2', filePath: 'b.mp3', fileName: 'B', startTimelineMs: 10000, durationMs: 10000, orderIndex: 1),
      ];

      final updated = AudioEditingService.updateVolume(clips: clips, clipId: '2', volume: 0.65);
      expect(updated[0].volume, equals(1.0));
      expect(updated[1].volume, equals(0.65));
    });

    test('Deletes audio clip and ripples subsequent clips', () {
      final clips = [
        const AudioClipItem(id: '1', filePath: '1.mp3', fileName: '1', startTimelineMs: 0, durationMs: 10000, orderIndex: 0),
        const AudioClipItem(id: '2', filePath: '2.mp3', fileName: '2', startTimelineMs: 10000, durationMs: 20000, orderIndex: 1),
        const AudioClipItem(id: '3', filePath: '3.mp3', fileName: '3', startTimelineMs: 30000, durationMs: 15000, orderIndex: 2),
      ];

      final remaining = AudioEditingService.deleteAudioClip(clips: clips, clipId: '2');
      expect(remaining.length, equals(2));
      expect(remaining[0].id, equals('1'));
      expect(remaining[1].id, equals('3'));
      expect(remaining[1].startTimelineMs, equals(10000));
    });

    test('Trims audio clip end reducing or extending duration', () {
      final clips = [
        const AudioClipItem(id: '1', filePath: 'song.mp3', fileName: 'Song', startTimelineMs: 5000, durationMs: 20000, orderIndex: 0),
      ];

      final trimmed = AudioEditingService.trimClipEnd(clips: clips, clipId: '1', newDurationMs: 12000);
      expect(trimmed.first.durationMs, equals(12000));
      expect(trimmed.first.endTimelineMs, equals(17000));
    });

    test('Trims audio clip start adjusting startTimelineMs, fileStartOffsetMs, and durationMs', () {
      final clips = [
        const AudioClipItem(id: '1', filePath: 'song.mp3', fileName: 'Song', startTimelineMs: 0, fileStartOffsetMs: 0, durationMs: 72000, orderIndex: 0),
      ];

      // Drag left trim handle from 0 to 8300ms (so audio starts at image 2)
      final trimmed = AudioEditingService.trimClipStart(clips: clips, clipId: '1', newStartTimelineMs: 8300);
      expect(trimmed.first.startTimelineMs, equals(8300));
      expect(trimmed.first.fileStartOffsetMs, equals(8300));
      expect(trimmed.first.durationMs, equals(72000 - 8300));
      expect(trimmed.first.endTimelineMs, equals(72000));
    });

    test('Moving audio clips preserves chronological sorting and orders', () {
      final clips = [
        const AudioClipItem(id: '1', filePath: 'a.mp3', fileName: 'A', startTimelineMs: 0, durationMs: 10000, orderIndex: 0),
        const AudioClipItem(id: '2', filePath: 'b.mp3', fileName: 'B', startTimelineMs: 10000, durationMs: 10000, orderIndex: 1),
      ];

      final moved = AudioEditingService.moveClipStart(clips: clips, clipId: '1', newStartMs: 25000);
      expect(moved[0].id, equals('2'));
      expect(moved[0].orderIndex, equals(0));
      expect(moved[1].id, equals('1'));
      expect(moved[1].orderIndex, equals(1));
      expect(moved[1].startTimelineMs, equals(25000));
    });

    test('Updates audio source range (e.g., 5:00 to 8:00 of a 10:00 audio)', () {
      final clips = [
        const AudioClipItem(
          id: '1',
          filePath: 'long.mp3',
          fileName: 'Long Audio',
          startTimelineMs: 0,
          durationMs: 600000,
          sourceDurationMs: 600000,
          orderIndex: 0,
        ),
      ];

      final ranged = AudioEditingService.updateSourceRange(
        clips: clips,
        clipId: '1',
        sourceStartMs: 300000, // 05:00
        sourceEndMs: 480000,   // 08:00
      );

      expect(ranged.first.fileStartOffsetMs, equals(300000));
      expect(ranged.first.durationMs, equals(180000));
      expect(ranged.first.sourceDurationMs, equals(600000));
      expect(ranged.first.startTimelineMs, equals(0));
    });
  });
}
