import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/asset_transform.dart';
import '../../../models/image_item.dart';

class TransformGizmo extends StatefulWidget {
  final AssetTransform transform;
  final Size canvasSize;
  final Size? naturalImageSize;
  final ImageFitMode fitMode;
  final ValueChanged<AssetTransform> onTransformChanged;
  final ValueChanged<AssetTransform> onTransformCommitted;

  const TransformGizmo({
    super.key,
    required this.transform,
    required this.canvasSize,
    this.naturalImageSize,
    this.fitMode = ImageFitMode.fit,
    required this.onTransformChanged,
    required this.onTransformCommitted,
  });

  @override
  State<TransformGizmo> createState() => _TransformGizmoState();
}

class _TransformGizmoState extends State<TransformGizmo> {
  late AssetTransform _current;
  bool _isInteracting = false;
  String _activeFeedback = '';

  @override
  void initState() {
    super.initState();
    _current = widget.transform;
  }

  @override
  void didUpdateWidget(covariant TransformGizmo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isInteracting && widget.transform != oldWidget.transform) {
      _current = widget.transform;
    }
  }

  void _onMoveUpdate(DragUpdateDetails details) {
    final dx = details.delta.dx / (widget.canvasSize.width * 0.5);
    final dy = details.delta.dy / (widget.canvasSize.height * 0.5);
    setState(() {
      _isInteracting = true;
      _current = _current.copyWith(
        positionX: (_current.positionX + dx).clamp(-2.0, 2.0),
        positionY: (_current.positionY + dy).clamp(-2.0, 2.0),
      );
      _activeFeedback = 'X: ${(_current.positionX * 100).round()}%  Y: ${(_current.positionY * 100).round()}%';
    });
    widget.onTransformChanged(_current);
  }

  void _onScaleUpdate(DragUpdateDetails details, {required double dirX, required double dirY}) {
    final scaleDelta = (details.delta.dx * dirX + details.delta.dy * dirY) / 100.0;
    setState(() {
      _isInteracting = true;
      final newScale = (_current.scaleX + scaleDelta).clamp(0.1, 5.0);
      _current = _current.copyWith(scaleX: newScale, scaleY: newScale);
      _activeFeedback = 'Scale: ${(newScale * 100).round()}%';
    });
    widget.onTransformChanged(_current);
  }

  void _onRotateUpdate(DragUpdateDetails details, Offset center) {
    final angle = atan2(details.localPosition.dy - center.dy, details.localPosition.dx - center.dx);
    setState(() {
      _isInteracting = true;
      _current = _current.copyWith(rotation: angle);
      _activeFeedback = 'Rot: ${(angle * 180 / pi).round()}°';
    });
    widget.onTransformChanged(_current);
  }

  void _onGestureEnd() {
    setState(() {
      _isInteracting = false;
      _activeFeedback = '';
    });
    widget.onTransformCommitted(_current);
  }

  Widget _handle(MouseCursor cursor, Function(DragUpdateDetails) onUpdate) {
    return GestureDetector(
      onPanUpdate: onUpdate,
      onPanEnd: (_) => _onGestureEnd(),
      child: MouseRegion(
        cursor: cursor,
        child: Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            color: Colors.white, shape: BoxShape.circle,
            border: Border.all(color: AppColors.accentBlue, width: 2),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cW = widget.canvasSize.width;
    final cH = widget.canvasSize.height;
    double baseW = cW;
    double baseH = cH;

    if (widget.naturalImageSize != null && widget.fitMode == ImageFitMode.fit && widget.naturalImageSize!.height > 0) {
      final imgAspect = widget.naturalImageSize!.width / widget.naturalImageSize!.height;
      final canvasAspect = cW / cH;
      if (imgAspect > canvasAspect) {
        baseW = cW;
        baseH = cW / imgAspect;
      } else {
        baseH = cH;
        baseW = cH * imgAspect;
      }
    }

    final boxW = baseW * _current.scaleX;
    final boxH = baseH * _current.scaleY;
    final centerX = (cW * 0.5) + (_current.positionX * cW * 0.5);
    final centerY = (cH * 0.5) + (_current.positionY * cH * 0.5);

    return Positioned(
      left: centerX - (boxW * 0.5),
      top: centerY - (boxH * 0.5),
      width: boxW,
      height: boxH,
      child: Transform.rotate(
        angle: _current.rotation,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onPanUpdate: _onMoveUpdate,
              onPanEnd: (_) => _onGestureEnd(),
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.9), width: 1.5),
                    color: AppColors.accentBlue.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ),
            Positioned(left: -6, top: -6, child: _handle(SystemMouseCursors.resizeUpLeftDownRight, (d) => _onScaleUpdate(d, dirX: -1, dirY: -1))),
            Positioned(right: -6, top: -6, child: _handle(SystemMouseCursors.resizeUpRightDownLeft, (d) => _onScaleUpdate(d, dirX: 1, dirY: -1))),
            Positioned(left: -6, bottom: -6, child: _handle(SystemMouseCursors.resizeUpRightDownLeft, (d) => _onScaleUpdate(d, dirX: -1, dirY: 1))),
            Positioned(right: -6, bottom: -6, child: _handle(SystemMouseCursors.resizeUpLeftDownRight, (d) => _onScaleUpdate(d, dirX: 1, dirY: 1))),
            Positioned(
              left: (boxW * 0.5) - 6, top: -26,
              child: _handle(SystemMouseCursors.click, (d) => _onRotateUpdate(d, Offset(boxW * 0.5, boxH * 0.5))),
            ),
            Positioned(
              left: (boxW * 0.5) - 0.5, top: -20,
              child: Container(width: 1, height: 14, color: AppColors.accentBlue),
            ),
            if (_activeFeedback.isNotEmpty)
              Positioned(
                bottom: -28, left: (boxW * 0.5) - 45,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.accentBlue, width: 0.5)),
                  child: Text(_activeFeedback, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
