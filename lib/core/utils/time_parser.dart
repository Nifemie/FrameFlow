/// Utility for parsing and formatting timestamps in FrameFlow.
/// All internal video calculations use integer milliseconds.
class TimeParser {
  /// Parses a flexible user-entered string into integer milliseconds.
  /// 
  /// Accepted formats:
  /// - Pure seconds: "5", "5.5", "5,5" -> 5000ms, 5500ms
  /// - MM:SS : "01:30" -> 90000ms
  /// - MM:SS.mmm : "01:30.500", "01:30,500" -> 90500ms
  /// - HH:MM:SS : "01:05:20" -> 3920000ms
  /// - HH:MM:SS.mmm : "01:05:20.250" -> 3920250ms
  /// 
  /// Returns `null` if the input is empty or invalid.
  static int? parseToMs(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Normalize comma decimal separator to dot
    final normalized = trimmed.replaceAll(',', '.');

    // Case 1: Pure number (seconds) e.g. "5", "5.5"
    final directSeconds = double.tryParse(normalized);
    if (directSeconds != null) {
      if (directSeconds < 0) return null;
      return (directSeconds * 1000).round();
    }

    // Case 2: Colon-separated parts
    final parts = normalized.split(':');
    if (parts.length == 2) {
      // MM:SS or MM:SS.mmm
      final minutes = int.tryParse(parts[0]);
      final seconds = double.tryParse(parts[1]);
      if (minutes == null || seconds == null || minutes < 0 || seconds < 0) {
        return null;
      }
      return ((minutes * 60 + seconds) * 1000).round();
    } else if (parts.length == 3) {
      // HH:MM:SS or HH:MM:SS.mmm
      final hours = int.tryParse(parts[0]);
      final minutes = int.tryParse(parts[1]);
      final seconds = double.tryParse(parts[2]);
      if (hours == null || minutes == null || seconds == null ||
          hours < 0 || minutes < 0 || seconds < 0) {
        return null;
      }
      return ((hours * 3600 + minutes * 60 + seconds) * 1000).round();
    }

    return null;
  }

  /// Formats milliseconds to standard display "MM:SS" or "HH:MM:SS" if >= 1 hour.
  static String formatStandard(int ms) {
    if (ms < 0) ms = 0;
    final totalSeconds = ms ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final hStr = hours.toString().padLeft(2, '0');
      return '$hStr:$mStr:$sStr';
    }
    return '$mStr:$sStr';
  }

  /// Formats milliseconds to detailed "MM:SS.mmm" or "HH:MM:SS.mmm".
  static String formatDetailed(int ms) {
    if (ms < 0) ms = 0;
    final totalSeconds = ms ~/ 1000;
    final milliseconds = ms % 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    final msStr = milliseconds.toString().padLeft(3, '0');

    if (hours > 0) {
      final hStr = hours.toString().padLeft(2, '0');
      return '$hStr:$mStr:$sStr.$msStr';
    }
    return '$mStr:$sStr.$msStr';
  }

  /// Formats milliseconds to SMPTE timecode: "HH:MM:SS:FF" based on FPS.
  static String formatSMPTE(int ms, {int fps = 30}) {
    if (ms < 0) ms = 0;
    final totalFrames = (ms * fps / 1000).floor();
    final frames = totalFrames % fps;
    final totalSeconds = totalFrames ~/ fps;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final hStr = hours.toString().padLeft(2, '0');
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    final fStr = frames.toString().padLeft(2, '0');

    return '$hStr:$mStr:$sStr:$fStr';
  }
}
