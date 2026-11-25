import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/text_overlay_item.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';

class AnimatedTextOverlay extends ConsumerStatefulWidget {
  final TextOverlayItem item;
  final int playheadMs;

  const AnimatedTextOverlay({super.key, required this.item, required this.playheadMs});

  @override
  ConsumerState<AnimatedTextOverlay> createState() => _AnimatedTextOverlayState();
}

class _AnimatedTextOverlayState extends ConsumerState<AnimatedTextOverlay> {
  double _dragX = 0.0;
  double _dragY = 0.0;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final playheadMs = widget.playheadMs;
    if (playheadMs < item.startMs || playheadMs > item.endMs) return const SizedBox.shrink();

    final isSelected = ref.watch(selectedTextOverlayIdProvider) == item.id;
    final elapsed = playheadMs - item.startMs;
    final remaining = item.endMs - playheadMs;
    final inMs = max(50, item.animationDurationMs);
    final outMs = max(50, item.animationOutDurationMs);
    final pIn = (elapsed / inMs).clamp(0.0, 1.0);
    final pOut = (remaining / outMs).clamp(0.0, 1.0);

    double opacity = item.opacity;
    double scale = item.scale;
    double offsetX = 0.0, offsetY = 0.0, rotation = 0.0;
    String displayText = item.text;

    switch (item.animationType) {
      case TextAnimationType.fadeIn: opacity *= pIn; break;
      case TextAnimationType.fadeOut: opacity *= pOut; break;
      case TextAnimationType.fadeBoth: opacity *= (elapsed < inMs ? pIn : pOut); break;
      case TextAnimationType.slideUp:
        if (elapsed < inMs) { offsetY = (1.0 - pIn) * 40.0; opacity *= pIn; }
        else if (remaining < outMs) { offsetY = -(1.0 - pOut) * 40.0; opacity *= pOut; }
        break;
      case TextAnimationType.slideDown:
        if (elapsed < inMs) { offsetY = -(1.0 - pIn) * 40.0; opacity *= pIn; }
        else if (remaining < outMs) { offsetY = (1.0 - pOut) * 40.0; opacity *= pOut; }
        break;
      case TextAnimationType.slideLeft:
        if (elapsed < inMs) { offsetX = (1.0 - pIn) * 60.0; opacity *= pIn; }
        else if (remaining < outMs) { offsetX = -(1.0 - pOut) * 60.0; opacity *= pOut; }
        break;
      case TextAnimationType.slideRight:
        if (elapsed < inMs) { offsetX = -(1.0 - pIn) * 60.0; opacity *= pIn; }
        else if (remaining < outMs) { offsetX = (1.0 - pOut) * 60.0; opacity *= pOut; }
        break;
      case TextAnimationType.zoomIn:
        if (elapsed < inMs) { scale *= pIn; opacity *= pIn; }
        else if (remaining < outMs) { scale *= pOut; opacity *= pOut; }
        break;
      case TextAnimationType.bounce:
        if (elapsed < inMs) { scale *= Curves.elasticOut.transform(pIn); opacity *= pIn; }
        else if (remaining < outMs) { scale *= pOut; opacity *= pOut; }
        break;
      case TextAnimationType.typewriter:
        if (elapsed < inMs && item.text.isNotEmpty) {
          final count = (item.text.length * pIn).round().clamp(1, item.text.length);
          displayText = item.text.substring(0, count);
        } else if (remaining < outMs) { opacity *= pOut; }
        break;
      case TextAnimationType.rotateIn:
        if (elapsed < inMs) { rotation = (1.0 - pIn) * -0.5; opacity *= pIn; scale *= (0.5 + 0.5 * pIn); }
        else if (remaining < outMs) { opacity *= pOut; }
        break;
      case TextAnimationType.popScale:
        if (elapsed < inMs) { scale *= (0.2 + 0.8 * Curves.easeOutBack.transform(pIn)); opacity *= pIn; }
        else if (remaining < outMs) { scale *= pOut; opacity *= pOut; }
        break;
      case TextAnimationType.none: break;
    }

    final shadows = item.hasShadow ? [Shadow(color: item.shadowColor, blurRadius: item.shadowBlur, offset: Offset(item.shadowOffsetX, item.shadowOffsetY))] : null;
    final style = TextStyle(fontFamily: item.fontFamily, fontSize: item.fontSize, color: item.textColor, fontWeight: FontWeight.bold, shadows: shadows);

    return Align(
      alignment: Alignment(item.positionX, item.positionY),
      child: Transform.translate(
        offset: Offset(offsetX, offsetY),
        child: Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: MouseRegion(
                cursor: SystemMouseCursors.move,
                child: GestureDetector(
                  onTap: () {
                    ref.read(selectedTextOverlayIdProvider.notifier).state = item.id;
                    ref.read(selectedImageIdProvider.notifier).state = null;
                  },
                  onPanStart: (_) {
                    _dragX = item.positionX;
                    _dragY = item.positionY;
                    ref.read(projectProvider.notifier).recordSnapshot();
                  },
                  onPanUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    final w = (box != null && box.hasSize && box.size.width > 50) ? box.size.width : 500.0;
                    final h = (box != null && box.hasSize && box.size.height > 50) ? box.size.height : 300.0;
                    _dragX = (_dragX + (details.delta.dx / (w / 2.0))).clamp(-1.0, 1.0);
                    _dragY = (_dragY + (details.delta.dy / (h / 2.0))).clamp(-1.0, 1.0);
                    ref.read(projectProvider.notifier).updateTextOverlay(
                      item.copyWith(positionX: _dragX, positionY: _dragY),
                      recordUndo: false,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: isSelected ? BoxDecoration(border: Border.all(color: Colors.amber, width: 1.5), borderRadius: BorderRadius.circular(4)) : null,
                    child: item.hasOutline
                        ? Stack(
                            children: [
                              Text(displayText, style: style.copyWith(foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = item.outlineWidth..color = item.outlineColor)),
                              Text(displayText, style: style),
                            ],
                          )
                        : Text(displayText, style: style),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
