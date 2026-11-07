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

      // If line contains commas, check if it's CSV
      if (trimmed.contains(',')) {
        final cols = trimmed.split(',');
        // Skip CSV header line if present
        if (cols[0].toLowerCase().contains('index') ||
            cols[0].toLowerCase().contains('file') ||
            cols[0].toLowerCase().contains('name')) {
          continue;
        }

        // Try finding the column that parses as a timestamp
        String? foundStamp;
        for (final col in cols) {
          final cleanCol = col.replaceAll('"', '').trim();
          if (TimeParser.parseToMs(cleanCol) != null) {
            foundStamp = cleanCol;
          }
        }
        if (foundStamp != null) {
          results.add(foundStamp);
        }
      } else {
        // Plain timestamp per line
        if (TimeParser.parseToMs(trimmed) != null) {
          results.add(trimmed);
        }
      }
    }

    return results;
  }
}
