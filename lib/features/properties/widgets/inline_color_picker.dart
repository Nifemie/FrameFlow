import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/theme_provider.dart';

class InlineColorPicker extends ConsumerStatefulWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorChanged;
  final String title;

  const InlineColorPicker({
    super.key,
    required this.currentColor,
    required this.onColorChanged,
    required this.title,
  });

  @override
  ConsumerState<InlineColorPicker> createState() => _InlineColorPickerState();
}

class _InlineColorPickerState extends ConsumerState<InlineColorPicker> {
  late Color _color;
  late final TextEditingController _hexController;
  int _mode = 0; // 0: Wheel, 1: HSL, 2: RGB

  @override
  void initState() {
    super.initState();
    _color = widget.currentColor;
    _hexController = TextEditingController(text: _toHex(_color));
  }

  @override
  void didUpdateWidget(covariant InlineColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentColor.toARGB32() != widget.currentColor.toARGB32()) {
      _color = widget.currentColor;
      _hexController.text = _toHex(_color);
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _toHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  void _setColor(Color next, {bool updateHex = true}) {
    final preserved = next.withValues(alpha: _color.a);
    setState(() {
      _color = preserved;
      if (updateHex) {
        _hexController.text = _toHex(preserved);
      }
    });
    widget.onColorChanged(preserved);
  }

  @override
  Widget build(BuildContext context) {
    final recommended = ref.watch(recommendedColorsProvider);
    final recNotifier = ref.read(recommendedColorsProvider.notifier);

    final hsv = HSVColor.fromColor(_color);
    final hsl = HSLColor.fromColor(_color);
    final r = (_color.r * 255).round().clamp(0, 255);
    final g = (_color.g * 255).round().clamp(0, 255);
    final b = (_color.b * 255).round().clamp(0, 255);

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 26,
                decoration: BoxDecoration(
                  color: _color,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white38),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: TextField(
                    controller: _hexController,
                    style: const TextStyle(fontSize: 10.5, color: Colors.white, fontFamily: 'Consolas'),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      hintText: '#HEX',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: AppColors.surfaceBorder),
                      ),
                    ),
                    onChanged: (val) {
                      final clean = val.replaceAll('#', '').trim();
                      if (clean.length == 6) {
                        final parsed = int.tryParse('FF$clean', radix: 16);
                        if (parsed != null) {
                          _setColor(Color(parsed), updateHex: false);
                        }
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Mode selector: Wheel | HSL | RGB
          Row(
            children: [
              _modeTab(0, 'Wheel'),
              const SizedBox(width: 4),
              _modeTab(1, 'HSL'),
              const SizedBox(width: 4),
              _modeTab(2, 'RGB'),
            ],
          ),
          const SizedBox(height: 10),

          if (_mode == 0) ...[
            Center(
              child: _InlineColorWheel(
                hsvColor: hsv,
                size: 136,
                onChanged: (nextHsv) => _setColor(nextHsv.toColor()),
              ),
            ),
            const SizedBox(height: 8),
            _InlineSlider(
              label: 'Brightness',
              valueText: '${(hsv.value * 100).round()}%',
              value: hsv.value,
              max: 1.0,
              activeColor: _color,
              onChanged: (v) => _setColor(hsv.withValue(v).toColor()),
            ),
          ] else if (_mode == 1) ...[
            _InlineSlider(
              label: 'Hue (H)',
              valueText: '${hsl.hue.round()}°',
              value: hsl.hue,
              max: 360.0,
              activeColor: HSLColor.fromAHSL(1, hsl.hue, 1, 0.5).toColor(),
              onChanged: (v) => _setColor(hsl.withHue(v).toColor()),
            ),
            _InlineSlider(
              label: 'Saturation (S)',
              valueText: '${(hsl.saturation * 100).round()}%',
              value: hsl.saturation,
              max: 1.0,
              activeColor: _color,
              onChanged: (v) => _setColor(hsl.withSaturation(v).toColor()),
            ),
            _InlineSlider(
              label: 'Lightness (L)',
              valueText: '${(hsl.lightness * 100).round()}%',
              value: hsl.lightness,
              max: 1.0,
              activeColor: _color,
              onChanged: (v) => _setColor(hsl.withLightness(v).toColor()),
            ),
          ] else ...[
            _InlineSlider(
              label: 'Red (R)',
              valueText: '$r',
              value: r.toDouble(),
              max: 255.0,
              activeColor: Colors.redAccent,
              onChanged: (v) => _setColor(Color.fromARGB(255, v.round(), g, b)),
            ),
            _InlineSlider(
              label: 'Green (G)',
              valueText: '$g',
              value: g.toDouble(),
              max: 255.0,
              activeColor: Colors.greenAccent,
              onChanged: (v) => _setColor(Color.fromARGB(255, r, v.round(), b)),
            ),
            _InlineSlider(
              label: 'Blue (B)',
              valueText: '$b',
              value: b.toDouble(),
              max: 255.0,
              activeColor: Colors.blueAccent,
              onChanged: (v) => _setColor(Color.fromARGB(255, r, g, v.round())),
            ),
          ],

          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recommended',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              InkWell(
                onTap: () => recNotifier.addColor(_color),
                borderRadius: BorderRadius.circular(4),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    '+ Add',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.accentOrange),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: recommended.map((c) {
              final selected = c.toARGB32() == _color.toARGB32();
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: () => _setColor(c),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: c,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: selected ? Colors.white : AppColors.surfaceBorder,
                          width: selected ? 2.0 : 1,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: GestureDetector(
                      onTap: () => recNotifier.removeColor(c),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surfaceBorder, width: 0.7),
                        ),
                        child: const Icon(Icons.close, size: 8, color: Colors.white70),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _modeTab(int idx, String label) {
    final active = _mode == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _mode = idx),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.accentOrange.withValues(alpha: 0.2) : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: active ? AppColors.accentOrange : AppColors.surfaceBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: active ? AppColors.accentOrange : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineSlider extends StatelessWidget {
  final String label;
  final String valueText;
  final double value;
  final double max;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  const _InlineSlider({
    required this.label,
    required this.valueText,
    required this.value,
    required this.max,
    required this.activeColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary)),
            Text(valueText, style: const TextStyle(fontFamily: 'Consolas', fontSize: 9.5, color: Colors.white)),
          ],
        ),
        SizedBox(
          height: 22,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: activeColor,
              thumbColor: Colors.white,
              inactiveTrackColor: AppColors.surfaceBorder,
            ),
            child: Slider(
              value: value.clamp(0.0, max),
              min: 0.0,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineColorWheel extends StatelessWidget {
  final HSVColor hsvColor;
  final double size;
  final ValueChanged<HSVColor> onChanged;

  const _InlineColorWheel({
    required this.hsvColor,
    required this.size,
    required this.onChanged,
  });

  void _handlePointer(Offset localPos) {
    final radius = size / 2;
    final dx = localPos.dx - radius;
    final dy = localPos.dy - radius;
    final dist = sqrt(dx * dx + dy * dy);
    final sat = (dist / radius).clamp(0.0, 1.0);
    var angleDeg = atan2(dy, dx) * 180 / pi;
    if (angleDeg < 0) angleDeg += 360.0;
    onChanged(hsvColor.withHue(angleDeg).withSaturation(sat));
  }

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    final rad = hsvColor.hue * pi / 180.0;
    final dist = hsvColor.saturation * radius;
    final thumbX = radius + cos(rad) * dist;
    final thumbY = radius + sin(rad) * dist;

    return GestureDetector(
      onPanDown: (d) => _handlePointer(d.localPosition),
      onPanUpdate: (d) => _handlePointer(d.localPosition),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _InlineWheelPainter(hsvColor.value),
            ),
            Positioned(
              left: thumbX - 6,
              top: thumbY - 6,
              child: IgnorePointer(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hsvColor.toColor(),
                    border: Border.all(color: Colors.white, width: 1.8),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3)],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineWheelPainter extends CustomPainter {
  final double value;
  const _InlineWheelPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const hueColors = [
      Color(0xFFFF0000),
      Color(0xFFFFFF00),
      Color(0xFF00FF00),
      Color(0xFF00FFFF),
      Color(0xFF0000FF),
      Color(0xFFFF00FF),
      Color(0xFFFF0000),
    ];

    final huePaint = Paint()
      ..shader = const SweepGradient(colors: hueColors).createShader(rect);
    canvas.drawCircle(center, radius, huePaint);

    final satPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Colors.white, Color(0x00FFFFFF)],
      ).createShader(rect);
    canvas.drawCircle(center, radius, satPaint);

    if (value < 1.0) {
      final valPaint = Paint()..color = Colors.black.withValues(alpha: 1.0 - value);
      canvas.drawCircle(center, radius, valPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _InlineWheelPainter oldDelegate) => oldDelegate.value != value;
}
