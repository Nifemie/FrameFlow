import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/services/offline_timestamp_service.dart';

void main() {
  group('OfflineTimestampService Alignment Tests', () {
    test('Aligns script words and groups into sentences with exact timings', () {
      const script = 'Hello world! This is FrameFlow.';
      const tokens = [
        RecognizedWordToken(text: 'Hello', startMs: 100, endMs: 500),
        RecognizedWordToken(text: 'world', startMs: 520, endMs: 900),
        RecognizedWordToken(text: 'This', startMs: 1200, endMs: 1500),
        RecognizedWordToken(text: 'is', startMs: 1520, endMs: 1700),
        RecognizedWordToken(text: 'FrameFlow', startMs: 1720, endMs: 2400),
      ];

      final sentenceRows = OfflineTimestampService.alignScriptToTokens(
        scriptText: script,
        recognizedTokens: tokens,
        granularity: TimestampGranularity.sentence,
        totalAudioMs: 3000,
      );

      expect(sentenceRows.length, equals(2));
      expect(sentenceRows[0].index, equals(1));
      expect(sentenceRows[0].text, equals('Hello world!'));
      expect(sentenceRows[0].startMs, equals(100));
      expect(sentenceRows[0].endMs, equals(900));

      expect(sentenceRows[1].index, equals(2));
      expect(sentenceRows[1].text, equals('This is FrameFlow.'));
      expect(sentenceRows[1].startMs, equals(1200));
      expect(sentenceRows[1].endMs, equals(2400));

      final wordRows = OfflineTimestampService.alignScriptToTokens(
        scriptText: script,
        recognizedTokens: tokens,
        granularity: TimestampGranularity.word,
        totalAudioMs: 3000,
      );
      expect(wordRows.length, equals(5));
      expect(wordRows[4].text, equals('FrameFlow.'));
      expect(wordRows[4].formatTimestamp(TimestampFormatMode.beginningOnly), equals('00:01.72'));
      expect(wordRows[4].formatTimestamp(TimestampFormatMode.endingOnly), equals('00:02.40'));
      expect(wordRows[4].formatTimestamp(TimestampFormatMode.both), equals('00:01.72 - 00:02.40'));
    });

    test('Interpolates unmatched words smoothly between recognized anchors', () {
      const script = 'Welcome to FrameFlow Studio today.';
      const tokens = [
        RecognizedWordToken(text: 'Welcome', startMs: 0, endMs: 400),
        RecognizedWordToken(text: 'today', startMs: 2000, endMs: 2500),
      ];

      final wordRows = OfflineTimestampService.alignScriptToTokens(
        scriptText: script,
        recognizedTokens: tokens,
        granularity: TimestampGranularity.word,
        totalAudioMs: 3000,
      );

      expect(wordRows.length, equals(5));
      expect(wordRows[0].startMs, equals(0));
      expect(wordRows[4].startMs, equals(2000));
      expect(wordRows[1].startMs, greaterThanOrEqualTo(400));
      expect(wordRows[3].endMs, lessThanOrEqualTo(2000));
    });
  });
}
