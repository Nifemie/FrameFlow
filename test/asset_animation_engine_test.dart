import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/models/asset_transform.dart';
import 'package:frameflow/models/image_item.dart';
import 'package:frameflow/services/animation_library.dart';
import 'package:frameflow/services/animation_transform_evaluator.dart';
import 'package:frameflow/services/ffmpeg_animation_filter_builder.dart';

void main() {
  group('AssetAnimation & Evaluator Tests', () {
    test('Identity transform leaves asset values unchanged', () {
      final res = AnimationTransformEvaluator.evaluate(
        baseTransform: AssetTransform.identity,
        animations: const [],
        clipElapsedMs: 1000,
        clipDurationMs: 5000,
      );
      expect(res.positionX, 0.0);
      expect(res.positionY, 0.0);
      expect(res.scaleX, 1.0);
      expect(res.opacity, 1.0);
    });

    test('FadeIn entrance scales opacity from 0 to 1 smoothly', () {
      final anim = AnimationLibrary.findById('fadeIn')!.toAssetAnimation(durationMs: 1000);
      final atStart = AnimationTransformEvaluator.evaluate(
        baseTransform: AssetTransform.identity,
        animations: [anim],
        clipElapsedMs: 0,
        clipDurationMs: 5000,
      );
      expect(atStart.opacity, closeTo(0.0, 0.01));

      final atEnd = AnimationTransformEvaluator.evaluate(
        baseTransform: AssetTransform.identity,
        animations: [anim],
        clipElapsedMs: 1000,
        clipDurationMs: 5000,
      );
      expect(atEnd.opacity, closeTo(1.0, 0.01));
    });

    test('Toggling isExit true transforms animation into exit phase', () {
      final animOut = AnimationLibrary.findById('fadeIn')!.toAssetAnimation(durationMs: 1000, isExit: true);
      final eval = AnimationTransformEvaluator.evaluate(
        baseTransform: AssetTransform.identity,
        animations: [animOut],
        clipElapsedMs: 4500, // 500ms remaining out of 5000ms
        clipDurationMs: 5000,
      );
      expect(eval.opacity, lessThan(0.9));
    });

    test('Directional override moves along specified axis', () {
      final animTop = AnimationLibrary.findById('slideInLeft')!.toAssetAnimation(
        durationMs: 800,
        direction: 'top',
      );
      final atStart = AnimationTransformEvaluator.evaluate(
        baseTransform: AssetTransform.identity,
        animations: [animTop],
        clipElapsedMs: 0,
        clipDurationMs: 4000,
      );
      expect(atStart.positionY, lessThan(-0.5));
      expect(atStart.positionX, 0.0);
    });

    test('ZoomIn entrance scales from 0 up to 1', () {
      final anim = AnimationLibrary.findById('zoomIn')!.toAssetAnimation(durationMs: 800);
      final atStart = AnimationTransformEvaluator.evaluate(
        baseTransform: AssetTransform.identity,
        animations: [anim],
        clipElapsedMs: 0,
        clipDurationMs: 4000,
      );
      expect(atStart.scaleX, closeTo(0.0, 0.01));

      final atFinish = AnimationTransformEvaluator.evaluate(
        baseTransform: AssetTransform.identity,
        animations: [anim],
        clipElapsedMs: 800,
        clipDurationMs: 4000,
      );
      expect(atFinish.scaleX, closeTo(1.0, 0.01));
    });

    test('SlowZoomIn continuously expands scale across clip duration', () {
      final anim = AnimationLibrary.findById('slowZoomIn')!.toAssetAnimation();
      final atStart = AnimationTransformEvaluator.evaluate(
        baseTransform: AssetTransform.identity,
        animations: [anim],
        clipElapsedMs: 0,
        clipDurationMs: 4000,
      );
      final atEnd = AnimationTransformEvaluator.evaluate(
        baseTransform: AssetTransform.identity,
        animations: [anim],
        clipElapsedMs: 4000,
        clipDurationMs: 4000,
      );
      expect(atStart.scaleX, 1.0);
      expect(atEnd.scaleX, greaterThan(1.10));
    });

    test('SlideInLeft moves from negative X towards 0', () {
      final anim = AnimationLibrary.findById('slideInLeft')!.toAssetAnimation(durationMs: 600);
      final atStart = AnimationTransformEvaluator.evaluate(
        baseTransform: AssetTransform.identity,
        animations: [anim],
        clipElapsedMs: 0,
        clipDurationMs: 3000,
      );
      expect(atStart.positionX, lessThan(-0.5));

      final atEnd = AnimationTransformEvaluator.evaluate(
        baseTransform: AssetTransform.identity,
        animations: [anim],
        clipElapsedMs: 600,
        clipDurationMs: 3000,
      );
      expect(atEnd.positionX, closeTo(0.0, 0.01));
    });

    test('Multiple stacked animations combine multiplicatively and additively', () {
      final animFade = AnimationLibrary.findById('fadeIn')!.toAssetAnimation(durationMs: 500);
      final animZoom = AnimationLibrary.findById('slowZoomIn')!.toAssetAnimation();
      final eval = AnimationTransformEvaluator.evaluate(
        baseTransform: AssetTransform.identity,
        animations: [animFade, animZoom],
        clipElapsedMs: 500,
        clipDurationMs: 4000,
      );
      expect(eval.opacity, closeTo(1.0, 0.01));
      expect(eval.scaleX, greaterThan(1.01));
    });

    test('FFmpeg filter builder generates valid scale and fade filters', () {
      final anim = AnimationLibrary.findById('fadeIn')!.toAssetAnimation(durationMs: 500);
      final item = ImageItem(
        id: '1', filePath: 'test.jpg', displayName: 'test.jpg', orderIndex: 0, durationMs: 3000,
        transform: const AssetTransform(scaleX: 1.2, scaleY: 1.2, positionX: 0.1),
        animations: [anim],
      );
      final filter = FFmpegAnimationFilterBuilder.buildClipFilter(item: item, width: 1920, height: 1080);
      expect(filter, contains('scale='));
      expect(filter, contains('pad=1920:1080'));
      expect(filter, contains('fade=t=in'));
    });
  });
}
