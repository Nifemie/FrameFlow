import 'dart:math';

/// Handles mathematical scaling and anchor calculations for timeline zooming and navigation.
class TimelineZoomController {
  static const double minZoom = 0.2;
  static const double maxZoom = 5.0;
  static const double defaultBasePxPerSec = 40.0;

  /// Returns pixels per second for a given zoom factor.
  static double pxPerSec(double zoom) => defaultBasePxPerSec * zoom;

  /// Calculates new scroll offset anchored at a specific screen X coordinate (e.g., mouse position).
  static double calculateAnchoredScroll({
    required double currentScroll,
    required double anchorScreenX,
    required double oldZoom,
    required double newZoom,
  }) {
    final oldPx = pxPerSec(oldZoom);
    final newPx = pxPerSec(newZoom);
    if (oldPx <= 0) return currentScroll;

    final timeAtAnchorSec = (currentScroll + anchorScreenX) / oldPx;
    final targetScroll = (timeAtAnchorSec * newPx) - anchorScreenX;
    return max(0.0, targetScroll);
  }

  /// Calculates new scroll offset anchored at playhead position in milliseconds.
  static double calculatePlayheadAnchoredScroll({
    required int playheadMs,
    required double currentScroll,
    required double viewportWidth,
    required double oldZoom,
    required double newZoom,
  }) {
    final oldPx = pxPerSec(oldZoom);
    final playheadScreenX = ((playheadMs / 1000) * oldPx) - currentScroll;

    // If playhead is on screen, anchor it; otherwise anchor to viewport center
    final anchorX = (playheadScreenX >= 0 && playheadScreenX <= viewportWidth)
        ? playheadScreenX
        : (viewportWidth / 2);

    return calculateAnchoredScroll(
      currentScroll: currentScroll,
      anchorScreenX: anchorX,
      oldZoom: oldZoom,
      newZoom: newZoom,
    );
  }

  /// Calculates zoom required to fit the entire project duration within the viewport.
  static double calculateFitZoom({
    required int totalDurationMs,
    required double viewportWidth,
    double horizontalPadding = 48.0,
  }) {
    if (totalDurationMs <= 0 || viewportWidth <= 0) return 1.0;
    final totalSec = totalDurationMs / 1000.0;
    final availableWidth = max(100.0, viewportWidth - horizontalPadding);
    final fitPxPerSec = availableWidth / totalSec;
    final calculatedZoom = fitPxPerSec / defaultBasePxPerSec;
    return calculatedZoom.clamp(minZoom, maxZoom);
  }
}
