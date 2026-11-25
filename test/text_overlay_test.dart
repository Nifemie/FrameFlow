import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/models/text_overlay_item.dart';
import 'package:frameflow/services/font_loader_service.dart';
import 'package:frameflow/services/text_editing_service.dart';

void main() {
  group('TextOverlayItem & Animation Tests', () {
    test('Default TextOverlayItem has correct in/out animation durations and defaults', () {
      const item = TextOverlayItem(
        id: 't1', text: 'Cinema Title', startMs: 2000, durationMs: 4000,
        animationDurationMs: 450, animationOutDurationMs: 500,
      );

      expect(item.id, 't1');
      expect(item.text, 'Cinema Title');
      expect(item.startMs, 2000);
      expect(item.durationMs, 4000);
      expect(item.endMs, 6000);
      expect(item.animationDurationMs, 450);
      expect(item.animationOutDurationMs, 500);
      expect(item.animationType, TextAnimationType.fadeIn);
    });

    test('Serializes to and from JSON correctly with new animation attributes', () {
      const original = TextOverlayItem(
        id: 't2', text: 'Breaking News', startMs: 1500, durationMs: 2500,
        fontFamily: 'Montserrat', fontSize: 48.0, textColor: Colors.yellow,
        hasShadow: true, shadowBlur: 8.0, hasOutline: true, outlineWidth: 3.0,
        positionX: 0.2, positionY: -0.5, scale: 1.25, opacity: 0.9,
        animationType: TextAnimationType.typewriter,
        animationDurationMs: 600, animationOutDurationMs: 400,
      );

      final json = original.toJson();
      final revived = TextOverlayItem.fromJson(json);

      expect(revived.id, original.id);
      expect(revived.text, original.text);
      expect(revived.animationType, TextAnimationType.typewriter);
      expect(revived.animationDurationMs, 600);
      expect(revived.animationOutDurationMs, 400);
      expect(revived.positionX, original.positionX);
      expect(revived.positionY, original.positionY);
    });

    test('All new animation types are valid and distinguishable', () {
      final animations = [
        TextAnimationType.slideLeft, TextAnimationType.slideRight,
        TextAnimationType.zoomIn, TextAnimationType.bounce,
        TextAnimationType.typewriter, TextAnimationType.rotateIn,
      ];
      for (final a in animations) {
        final item = TextOverlayItem(id: a.name, text: 'Test', startMs: 0, animationType: a);
        expect(item.animationType, a);
        final json = item.toJson();
        expect(TextOverlayItem.fromJson(json).animationType, a);
      }
    });

    test('TextEditingService adds, updates, deletes, and trims overlays', () {
      final t1 = TextEditingService.createDefaultOverlay(startMs: 1000, text: 'First');
      final t2 = TextEditingService.createDefaultOverlay(startMs: 5000, text: 'Second');

      var list = <TextOverlayItem>[];
      list = TextEditingService.addOverlay(list, t1);
      list = TextEditingService.addOverlay(list, t2);
      expect(list.length, 2);

      final updatedT1 = t1.copyWith(text: 'Updated First', fontSize: 50.0);
      list = TextEditingService.updateOverlay(list, updatedT1);
      expect(list[0].text, 'Updated First');
      expect(list[0].fontSize, 50.0);

      list = TextEditingService.trimOverlay(list, t1.id, durationMs: 4500);
      expect(list[0].durationMs, 4500);
      expect(list[0].endMs, 5500);

      final activeAt2000 = TextEditingService.findActiveOverlays(list, 2000);
      expect(activeAt2000.length, 1);
      expect(activeAt2000.first.id, t1.id);

      list = TextEditingService.deleteOverlay(list, t1.id);
      expect(list.length, 1);
      expect(list.first.id, t2.id);
    });

    test('FontLoaderService preset font list includes essential typography', () {
      expect(FontLoaderService.presetFontFamilies, contains('Roboto'));
      expect(FontLoaderService.presetFontFamilies, contains('Montserrat'));
      expect(FontLoaderService.presetFontFamilies, contains('Impact'));
      expect(FontLoaderService.presetFontFamilies, contains('Courier New'));
    });
  });
}
