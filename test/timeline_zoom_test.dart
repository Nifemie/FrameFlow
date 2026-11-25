import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/features/timeline/services/timeline_zoom_controller.dart';

void main() {
  group('TimelineZoomController Tests', () {
    test('Calculates pxPerSec linearly with zoom factor', () {
      expect(TimelineZoomController.pxPerSec(1.0), 40.0);
      expect(TimelineZoomController.pxPerSec(2.0), 80.0);
      expect(TimelineZoomController.pxPerSec(0.5), 20.0);
    });

    test('Anchors zoom around mouse screen position without drift', () {
      // 10s into timeline at zoom 1.0 (40px/sec) is 400px.
      // Mouse is at screen position 200px, so scroll offset is 200px.
      // Time under mouse = (200 + 200) / 40 = 10s.
      // If zoom doubles to 2.0 (80px/sec), 10s should still be at mouse screen position 200px.
      // Target scroll = (10s * 80px/sec) - 200px = 600px.
      final newScroll = TimelineZoomController.calculateAnchoredScroll(
        currentScroll: 200.0,
        anchorScreenX: 200.0,
        oldZoom: 1.0,
        newZoom: 2.0,
      );
      expect(newScroll, 600.0);
    });

    test('Calculates fit zoom to project duration within viewport', () {
      // Project is 60 seconds. Viewport is 1200px (effective 1200 - 48 = 1152px).
      // Fit px/sec = 1152 / 60 = 19.2 px/sec.
      // Zoom = 19.2 / 40.0 = 0.48.
      final fitZoom = TimelineZoomController.calculateFitZoom(
        totalDurationMs: 60000,
        viewportWidth: 1200,
      );
      expect(fitZoom, closeTo(0.48, 0.01));
    });

    test('Clamps fit zoom within safe bounds', () {
      // Extremely long project (2 hours = 7200s) on small screen (500px)
      final minFit = TimelineZoomController.calculateFitZoom(
        totalDurationMs: 7200000,
        viewportWidth: 500,
      );
      expect(minFit, TimelineZoomController.minZoom);

      // Extremely short project (1s) on huge screen (3840px)
      final maxFit = TimelineZoomController.calculateFitZoom(
        totalDurationMs: 1000,
        viewportWidth: 3840,
      );
      expect(maxFit, TimelineZoomController.maxZoom);
    });
  });
}
