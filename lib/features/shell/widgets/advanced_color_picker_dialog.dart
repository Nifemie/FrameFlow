import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../providers/theme_provider.dart';

class AdvancedColorPickerDialog extends ConsumerStatefulWidget {
  final String title;
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  const AdvancedColorPickerDialog({
    super.key,
    required this.title,
    required this.initialColor,
    required this.onColorChanged,
  });

  @override
  ConsumerState<AdvancedColorPickerDialog> createState() => _AdvancedColorPickerDialogState();
}

class _AdvancedColorPickerDialogState extends ConsumerState<AdvancedColorPickerDialog> {
  late Color _color;
  late TextEditingController _hexCtrl;
  int _mode = 0; // 0: Wheel, 1: HSL, 2: RGB

  @override
  void initState() {
    super.initState();
    _color = widget.initialColor;
    _hexCtrl = TextEditingController(text: _toHex(_color));
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  String _toHex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

  void _setColor(Color next, {bool updateHex = true}) {
    setState(() {
      _color = next;
      if (updateHex) {
        _hexCtrl.text = _toHex(next);
      }
    });
    widget.onColorChanged(next);
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

    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white54),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(widget.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mode selector: Wheel | HSL | RGB
              Row(
                children: [
                  _modeTab(0, 'Color Wheel'),
                  const SizedBox(width: 6),
                  _modeTab(1, 'HSL'),
                  const SizedBox(width: 6),
                  _modeTab(2, 'RGB'),
                ],
              ),
              const SizedBox(height: 14),

              if (_mode == 0) ...[
                Center(
                  child: _ColorWheel(
                    hsvColor: hsv,
                    size: 190,
                    onChanged: (nextHsv) => _setColor(nextHsv.toColor()),
                  ),
                ),
                const SizedBox(height: 12),
                _LabeledSlider(
                  label: 'Brightness',
                  valueText: '${(hsv.value * 100).round()}%',
                  value: hsv.value,
                  max: 1.0,
                  activeColor: _color,
                  onChanged: (v) => _setColor(hsv.withValue(v).toColor()),
                ),
              ] else if (_mode == 1) ...[
                _LabeledSlider(
                  label: 'Hue (H)',
                  valueText: '${hsl.hue.round()}°',
                  value: hsl.hue,
                  max: 360.0,
                  activeColor: HSLColor.fromAHSL(1, hsl.hue, 1, 0.5).toColor(),
                  onChanged: (v) => _setColor(hsl.withHue(v).toColor()),
                ),
                _LabeledSlider(
                  label: 'Saturation (S)',
                  valueText: '${(hsl.saturation * 100).round()}%',
                  value: hsl.saturation,
                  max: 1.0,
                  activeColor: _color,
                  onChanged: (v) => _setColor(hsl.withSaturation(v).toColor()),
                ),
                _LabeledSlider(
                  label: 'Lightness (L)',
                  valueText: '${(hsl.lightness * 100).round()}%',
                  value: hsl.lightness,
                  max: 1.0,
                  activeColor: _color,
                  onChanged: (v) => _setColor(hsl.withLightness(v).toColor()),
                ),
              ] else ...[
                _LabeledSlider(
                  label: 'Red (R)',
                  valueText: '$r',
                  value: r.toDouble(),
                  max: 255.0,
                  activeColor: Colors.redAccent,
                  onChanged: (v) => _setColor(Color.fromARGB(255, v.round(), g, b)),
                ),
                _LabeledSlider(
                  label: 'Green (G)',
                  valueText: '$g',
                  value: g.toDouble(),
                  max: 255.0,
                  activeColor: Colors.greenAccent,
                  onChanged: (v) => _setColor(Color.fromARGB(255, r, v.round(), b)),
                ),
                _LabeledSlider(
                  label: 'Blue (B)',
                  valueText: '$b',
                  value: b.toDouble(),
                  max: 255.0,
                  activeColor: Colors.blueAccent,
                  onChanged: (v) => _setColor(Color.fromARGB(255, r, g, v.round())),
                ),
              ],

              const SizedBox(height: 10),
              TextField(
                controller: _hexCtrl,
                style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Hex Color',
                  isDense: true,
                  prefixIcon: Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                  ),
                ),
                onChanged: (val) {
                  final clean = val.trim().replaceAll('#', '');
                  if (clean.length == 6) {
                    final parsed = int.tryParse('FF$clean', radix: 16);
                    if (parsed != null) {
                      _setColor(Color(parsed), updateHex: false);
                    }
                  }
                },
              ),

              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.surfaceBorder),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recommended Colors',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                  TextButton.icon(
                    onPressed: () => recNotifier.addColor(_color),
                    icon: const Icon(Icons.add, size: 13, color: AppColors.accentOrange),
                    label: const Text('Add Current', style: TextStyle(fontSize: 11, color: AppColors.accentOrange)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: recommended.map((c) {
                  final selected = c.toARGB32() == _color.toARGB32();
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => _setColor(c),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: selected ? Colors.white : AppColors.surfaceBorder,
                              width: selected ? 2.2 : 1,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -5,
                        right: -5,
                        child: GestureDetector(
                          onTap: () => recNotifier.removeColor(c),
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
                            ),
                            child: const Icon(Icons.close, size: 9, color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _modeTab(int idx, String label) {
    final active = _mode == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _mode = idx),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.accentOrange.withValues(alpha: 0.2) : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: active ? AppColors.accentOrange : AppColors.surfaceBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: active ? AppColors.accentOrange : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  final String label;
  final String valueText;
  final double value;
  final double max;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  const _LabeledSlider({
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
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Text(valueText, style: const TextStyle(fontFamily: 'Consolas', fontSize: 11, color: Colors.white)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
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
      ],
    );
  }
}

class _ColorWheel extends StatelessWidget {
  final HSVColor hsvColor;
  final double size;
  final ValueChanged<HSVColor> onChanged;

  const _ColorWheel({
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
              painter: _ColorWheelPainter(hsvColor.value),
            ),
            Positioned(
              left: thumbX - 7,
              top: thumbY - 7,
              child: IgnorePointer(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hsvColor.toColor(),
                    border: Border.all(color: Colors.white, width: 2),
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

class _ColorWheelPainter extends CustomPainter {
  final double value;
  const _ColorWheelPainter(this.value);

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
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) => oldDelegate.value != value;
}
