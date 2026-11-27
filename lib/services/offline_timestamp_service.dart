import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../core/utils/time_parser.dart';
import 'audio_probe_service.dart';
import 'ffmpeg_service.dart';

enum TimestampGranularity { sentence, word }

enum TimestampFormatMode {
  beginningOnly('Beginning Only'),
  endingOnly('Ending Only'),
  both('Both (Start - End)');

  final String label;
  const TimestampFormatMode(this.label);
}

class RecognizedWordToken {
  final String text;
  final int startMs;
  final int endMs;

  const RecognizedWordToken({
    required this.text,
    required this.startMs,
    required this.endMs,
  });
}

class GeneratedTimestampRow {
  final int index;
  int startMs;
  int endMs;
  String text;

  GeneratedTimestampRow({
    required this.index,
    required this.startMs,
    required this.endMs,
    required this.text,
  });

  String formatTimestamp(TimestampFormatMode mode) {
    switch (mode) {
      case TimestampFormatMode.beginningOnly:
        return TimeParser.formatStandard(startMs);
      case TimestampFormatMode.endingOnly:
        return TimeParser.formatStandard(endMs);
      case TimestampFormatMode.both:
        return '${TimeParser.formatStandard(startMs)} - ${TimeParser.formatStandard(endMs)}';
    }
  }
}

class OfflineTimestampService {
  static Future<String?> findWhisperCli() async {
    for (final p in [
      'assets/bin/whisper-cli.exe',
      'assets/bin/main.exe',
      'data/flutter_assets/assets/bin/whisper-cli.exe',
      'windows/runner/whisper-cli.exe',
    ]) {
      if (File(p).existsSync()) return p;
    }
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      for (final name in ['whisper-cli.exe', 'main.exe']) {
        final candidate = '$exeDir\\data\\flutter_assets\\assets\\bin\\$name';
        if (File(candidate).existsSync()) return candidate;
        final sibling = '$exeDir\\$name';
        if (File(sibling).existsSync()) return sibling;
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> findWhisperModel() async {
    for (final p in [
      'assets/bin/ggml-base.en.bin',
      'assets/bin/ggml-tiny.en.bin',
      'assets/bin/ggml-base.bin',
      'assets/bin/ggml-tiny.bin',
      'data/flutter_assets/assets/bin/ggml-base.en.bin',
      'data/flutter_assets/assets/bin/ggml-tiny.en.bin',
    ]) {
      if (File(p).existsSync()) return p;
    }
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      for (final name in ['ggml-base.en.bin', 'ggml-tiny.en.bin', 'ggml-base.bin', 'ggml-tiny.bin']) {
        final candidate = '$exeDir\\data\\flutter_assets\\assets\\bin\\$name';
        if (File(candidate).existsSync()) return candidate;
        final sibling = '$exeDir\\$name';
        if (File(sibling).existsSync()) return sibling;
      }
    } catch (_) {}
    return null;
  }

  static Future<List<GeneratedTimestampRow>> generateTimestamps({
    required String audioPath,
    required String scriptText,
    required TimestampGranularity granularity,
    void Function(String status)? onStatus,
  }) async {
    final ffmpeg = await FFmpegService.findFFmpeg();
    if (ffmpeg == null) throw Exception('FFmpeg executable not found.');

    final whisperCli = await findWhisperCli();
    if (whisperCli == null) {
      throw Exception('Offline speech engine (whisper-cli.exe) not found in assets/bin/.');
    }

    final modelPath = await findWhisperModel();
    if (modelPath == null) {
      throw Exception('Offline speech model (ggml-tiny.en.bin) not found in assets/bin/.');
    }

    if (!File(audioPath).existsSync()) {
      throw Exception('Audio file not found: $audioPath');
    }

    final tempDir = Directory.systemTemp.createTempSync('frameflow_ts_');
    try {
      onStatus?.call('Preparing audio (16kHz WAV)...');
      final wavPath = '${tempDir.path}\\audio_16k.wav';
      final ffRes = await Process.run(ffmpeg, [
        '-y',
        '-i', audioPath,
        '-ar', '16000',
        '-ac', '1',
        '-c:a', 'pcm_s16le',
        wavPath,
      ]);
      if (ffRes.exitCode != 0 || !File(wavPath).existsSync()) {
        throw Exception('Failed to decode audio for alignment.');
      }

      final audioDurationMs = await AudioProbeService.getAudioDurationMs(audioPath);

      onStatus?.call('Aligning script with audio offline...');
      final outBase = '${tempDir.path}\\aligned';
      final promptSnippet = scriptText.trim().replaceAll(RegExp(r'\s+'), ' ');
      final prompt = promptSnippet.length > 220 ? promptSnippet.substring(0, 220) : promptSnippet;

      final wRes = await Process.run(whisperCli, [
        '-m', modelPath,
        '-f', wavPath,
        '-ojf',
        '-of', outBase,
        '-ml', '1',
        if (prompt.isNotEmpty) ...['--prompt', prompt],
      ]);

      final jsonFile = File('$outBase.json');
      if (wRes.exitCode != 0 || !jsonFile.existsSync()) {
        throw Exception('Offline alignment failed (code ${wRes.exitCode}).');
      }

      final decoded = jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
      final recognized = parseWhisperJsonTokens(decoded);

      return alignScriptToTokens(
        scriptText: scriptText,
        recognizedTokens: recognized,
        granularity: granularity,
        totalAudioMs: audioDurationMs > 0 ? audioDurationMs : 10000,
      );
    } finally {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  /// Parses `whisper-cli -ojf` JSON output into word-level [RecognizedWordToken]s.
  static List<RecognizedWordToken> parseWhisperJsonTokens(Map<String, dynamic> json) {
    final segments = json['transcription'] as List<dynamic>? ?? const [];
    final tokens = <RecognizedWordToken>[];

    for (final seg in segments) {
      if (seg is! Map<String, dynamic>) continue;
      final segTokens = seg['tokens'] as List<dynamic>?;
      if (segTokens != null && segTokens.isNotEmpty) {
        String wordBuf = '';
        int? wordStart;
        int? wordEnd;

        void flushWord() {
          final clean = wordBuf.trim();
          if (clean.isNotEmpty && wordStart != null && wordEnd != null) {
            tokens.add(RecognizedWordToken(
              text: clean,
              startMs: wordStart!,
              endMs: max(wordStart! + 40, wordEnd!),
            ));
          }
          wordBuf = '';
          wordStart = null;
          wordEnd = null;
        }

        for (final tok in segTokens) {
          if (tok is! Map<String, dynamic>) continue;
          final rawText = tok['text'] as String? ?? '';
          if (rawText.startsWith('[') && rawText.endsWith(']')) continue;
          final offsets = tok['offsets'] as Map<String, dynamic>?;
          if (offsets == null) continue;
          final fromMs = offsets['from'] as int? ?? 0;
          final toMs = offsets['to'] as int? ?? fromMs;

          // Subword pieces in Whisper start with a leading space when a new word begins
          if (rawText.startsWith(' ') && wordBuf.isNotEmpty) {
            flushWord();
          }
          wordBuf += rawText;
          wordStart ??= fromMs;
          wordEnd = toMs;
        }
        flushWord();
      } else {
        // Fallback: split segment text evenly across segment offsets
        final segOffsets = seg['offsets'] as Map<String, dynamic>?;
        final segText = (seg['text'] as String? ?? '').trim();
        if (segOffsets != null && segText.isNotEmpty) {
          final sMs = segOffsets['from'] as int? ?? 0;
          final eMs = segOffsets['to'] as int? ?? (sMs + 1000);
          final words = segText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
          if (words.isNotEmpty) {
            final step = (eMs - sMs) / words.length;
            for (int i = 0; i < words.length; i++) {
              tokens.add(RecognizedWordToken(
                text: words[i],
                startMs: (sMs + i * step).round(),
                endMs: (sMs + (i + 1) * step).round(),
              ));
            }
          }
        }
      }
    }
    return tokens;
  }

  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Aligns the user's exact [scriptText] onto [recognizedTokens] using dynamic
  /// programming, interpolating any unmatched words smoothly so every word and
  /// sentence keeps the user's exact wording with monotonic timestamps.
  static List<GeneratedTimestampRow> alignScriptToTokens({
    required String scriptText,
    required List<RecognizedWordToken> recognizedTokens,
    required TimestampGranularity granularity,
    required int totalAudioMs,
  }) {
    final sentences = _splitIntoSentences(scriptText);
    if (sentences.isEmpty) return const [];

    // Flatten script words while remembering which sentence each word belongs to
    final scriptWords = <({String raw, String norm, int sentenceIdx})>[];
    for (int sIdx = 0; sIdx < sentences.length; sIdx++) {
      final words = sentences[sIdx].split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
      for (final w in words) {
        scriptWords.add((raw: w, norm: _norm(w), sentenceIdx: sIdx));
      }
    }
    if (scriptWords.isEmpty) return const [];

    final n = scriptWords.length;
    final m = recognizedTokens.length;
    final matchedStart = List<int?>.filled(n, null);
    final matchedEnd = List<int?>.filled(n, null);

    if (m > 0) {
      // Needleman-Wunsch alignment between scriptWords (n) and recognizedTokens (m)
      final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
      for (int i = 0; i <= n; i++) {
        dp[i][0] = -i;
      }
      for (int j = 0; j <= m; j++) {
        dp[0][j] = -j;
      }
      for (int i = 1; i <= n; i++) {
        final sw = scriptWords[i - 1].norm;
        for (int j = 1; j <= m; j++) {
          final rw = _norm(recognizedTokens[j - 1].text);
          final score = (sw.isNotEmpty && sw == rw) ? 2 : -1;
          dp[i][j] = max(
            dp[i - 1][j - 1] + score,
            max(dp[i - 1][j] - 1, dp[i][j - 1] - 1),
          );
        }
      }

      int i = n;
      int j = m;
      while (i > 0 && j > 0) {
        final sw = scriptWords[i - 1].norm;
        final rw = _norm(recognizedTokens[j - 1].text);
        final score = (sw.isNotEmpty && sw == rw) ? 2 : -1;
        if (dp[i][j] == dp[i - 1][j - 1] + score) {
          if (sw.isNotEmpty && sw == rw) {
            matchedStart[i - 1] = recognizedTokens[j - 1].startMs;
            matchedEnd[i - 1] = recognizedTokens[j - 1].endMs;
          }
          i--;
          j--;
        } else if (dp[i][j] == dp[i - 1][j] - 1) {
          i--;
        } else {
          j--;
        }
      }
    }

    // Interpolate any unmatched words between nearest matched anchors
    final wordStarts = List<int>.filled(n, 0);
    final wordEnds = List<int>.filled(n, 0);
    int idx = 0;
    while (idx < n) {
      if (matchedStart[idx] != null) {
        wordStarts[idx] = matchedStart[idx]!;
        wordEnds[idx] = max(wordStarts[idx] + 40, matchedEnd[idx]!);
        idx++;
        continue;
      }
      int nextMatch = idx + 1;
      while (nextMatch < n && matchedStart[nextMatch] == null) {
        nextMatch++;
      }
      final prevEnd = idx > 0 ? wordEnds[idx - 1] : 0;
      final nextStart = nextMatch < n ? matchedStart[nextMatch]! : totalAudioMs;
      final span = max(100, nextStart - prevEnd);
      final count = nextMatch - idx;
      final step = span / count;
      for (int k = 0; k < count; k++) {
        wordStarts[idx + k] = (prevEnd + k * step).round();
        wordEnds[idx + k] = max(wordStarts[idx + k] + 40, (prevEnd + (k + 1) * step).round());
      }
      idx = nextMatch;
    }

    if (granularity == TimestampGranularity.word) {
      return List.generate(
        n,
        (k) => GeneratedTimestampRow(
          index: k + 1,
          startMs: wordStarts[k],
          endMs: wordEnds[k],
          text: scriptWords[k].raw,
        ),
      );
    }

    // Group into sentences
    final rows = <GeneratedTimestampRow>[];
    for (int sIdx = 0; sIdx < sentences.length; sIdx++) {
      int? first;
      int? last;
      for (int k = 0; k < n; k++) {
        if (scriptWords[k].sentenceIdx == sIdx) {
          first ??= k;
          last = k;
        }
      }
      if (first != null && last != null) {
        rows.add(GeneratedTimestampRow(
          index: rows.length + 1,
          startMs: wordStarts[first],
          endMs: wordEnds[last],
          text: sentences[sIdx],
        ));
      }
    }
    return rows;
  }

  static List<String> _splitIntoSentences(String scriptText) {
    final normalized = scriptText.trim();
    if (normalized.isEmpty) return const [];
    final rawParts = normalized.split(RegExp(r'(?<=[.!?])\s+|\r?\n+'));
    return rawParts.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
}
