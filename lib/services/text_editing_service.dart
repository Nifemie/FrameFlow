import 'package:uuid/uuid.dart';
import '../models/text_overlay_item.dart';

class TextEditingService {
  static const _uuid = Uuid();

  static TextOverlayItem createDefaultOverlay({required int startMs, String text = 'FrameFlow Title'}) {
    return TextOverlayItem(
      id: _uuid.v4(),
      text: text,
      startMs: startMs,
      durationMs: 3000,
    );
  }

  static List<TextOverlayItem> addOverlay(List<TextOverlayItem> list, TextOverlayItem item) {
    return [...list, item];
  }

  static List<TextOverlayItem> updateOverlay(List<TextOverlayItem> list, TextOverlayItem updated) {
    return list.map((item) => item.id == updated.id ? updated : item).toList();
  }

  static List<TextOverlayItem> deleteOverlay(List<TextOverlayItem> list, String id) {
    return list.where((item) => item.id != id).toList();
  }

  static List<TextOverlayItem> trimOverlay(List<TextOverlayItem> list, String id, {int? startMs, int? durationMs}) {
    return list.map((item) {
      if (item.id != id) return item;
      final newStart = startMs ?? item.startMs;
      final newDur = durationMs != null ? (durationMs < 200 ? 200 : durationMs) : item.durationMs;
      return item.copyWith(startMs: newStart, durationMs: newDur);
    }).toList();
  }

  static List<TextOverlayItem> findActiveOverlays(List<TextOverlayItem> list, int playheadMs) {
    return list.where((item) => playheadMs >= item.startMs && playheadMs <= item.endMs).toList();
  }
}
