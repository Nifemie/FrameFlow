import '../../../core/utils/time_parser.dart';
import '../../../models/image_item.dart';

class CsvService {
  /// Generates CSV format content from current project images.
  static String exportToCsv(List<ImageItem> images) {
    final buffer = StringBuffer();
    buffer.writeln('Index,File Name,Start Time,End Time,Duration (s)');

    for (int i = 0; i < images.length; i++) {
      final img = images[i];
      final startStr = TimeParser.formatStandard(img.startMs);
      final endStr = TimeParser.formatStandard(img.endMs);
      final durStr = (img.durationMs / 1000).toStringAsFixed(2);
      buffer.writeln('${i + 1},"${img.displayName}",$startStr,$endStr,$durStr');
    }

    return buffer.toString();
  }

  /// Parses text from pasted content or a CSV file into a list of timestamp strings.
  static List<String> parseTimestampsFromText(String rawText) {
    if (rawText.trim().isEmpty) return [];

    final lines = rawText.split(RegExp(r'[\r\n]+'));
    final results = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      if (trimmed.contains(',')) {
        final cols = trimmed.split(',');
        if (cols[0].toLowerCase().contains('index') ||
            cols[0].toLowerCase().contains('file') ||
            cols[0].toLowerCase().contains('name')) {
          continue;
        }

        String? foundStamp;
        for (final col in cols) {
          final cleanCol = col.replaceAll('"', '').trim();
          if (isValidTimestampOrRange(cleanCol)) {
            foundStamp = cleanCol;
          }
        }
        if (foundStamp != null) {
          results.add(foundStamp);
        }
      } else {
        if (isValidTimestampOrRange(trimmed)) {
          results.add(trimmed);
        }
      }
    }

    return results;
  }

  /// Checks if a string is a valid single timestamp or a start-end range.
  static bool isValidTimestampOrRange(String text) {
    final rangeParts = splitRange(text);
    if (rangeParts != null) {
      final s = TimeParser.parseToMs(rangeParts[0]);
      final e = TimeParser.parseToMs(rangeParts[1]);
      return s != null && e != null && e > s;
    }
    return TimeParser.parseToMs(text.trim()) != null;
  }

  /// Splits a range string like "00:10 - 00:15" or "00:10 to 00:15".
  static List<String>? splitRange(String text) {
    for (final sep in [' - ', ' – ', ' — ', ' to ', ' -> ']) {
      if (text.contains(sep)) {
        final parts = text.split(sep);
        if (parts.length == 2) return [parts[0].trim(), parts[1].trim()];
      }
    }
    if (text.contains('-')) {
      final parts = text.split('-');
      if (parts.length == 2 && parts[0].contains(':') && parts[1].contains(':')) {
        return [parts[0].trim(), parts[1].trim()];
      }
    }
    return null;
  }
}
