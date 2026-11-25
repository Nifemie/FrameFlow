import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class InlineColorPicker extends StatefulWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorChanged;
  final String title;

  const InlineColorPicker({super.key, required this.currentColor, required this.onColorChanged, required this.title});

  @override
  State<InlineColorPicker> createState() => _InlineColorPickerState();
}

class _InlineColorPickerState extends State<InlineColorPicker> {
  late double _hue, _sat, _val, _alpha;
  late final TextEditingController _hexController;

  static const _rainbow = [Color(0xFFFF0000), Color(0xFFFF8000), Color(0xFFFFFF00), Color(0xFF00FF00), Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFF8000FF), Color(0xFFFF00FF), Color(0xFFFF0000)];
  static const _swatches = [Colors.white, Color(0xFFE2E8F0), Color(0xFF94A3B8), Colors.black, Colors.redAccent, Colors.amber, Colors.greenAccent, Colors.cyanAccent, Colors.blueAccent, Colors.purpleAccent, Colors.pinkAccent];

  @override
  void initState() {
    super.initState();
    _syncHsv(widget.currentColor);
    _hexController = TextEditingController(text: _toHex());
  }

  @override
  void didUpdateWidget(covariant InlineColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentColor != widget.currentColor) { _syncHsv(widget.currentColor); _hexController.text = _toHex(); }
  }

  void _syncHsv(Color c) {
    final hsv = HSVColor.fromColor(c);
    _hue = hsv.hue; _sat = hsv.saturation; _val = hsv.value; _alpha = hsv.alpha;
  }

  Color get _color => HSVColor.fromAHSV(_alpha, _hue, _sat, _val).toColor();
  String _toHex() => '#${_color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}'.toUpperCase();
  void _notify() => widget.onColorChanged(_color);

  void _onHexSubmitted(String hex) {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final val = int.tryParse(clean, radix: 16);
      if (val != null) { setState(() { _syncHsv(Color(0xFF000000 | val).withValues(alpha: _alpha)); _hexController.text = _toHex(); }); _notify(); }
    }
  }

  @override
  void dispose() { _hexController.dispose(); super.dispose(); }

  Widget _buildBar({required Gradient gradient, required double value, required double min, required double max, required ValueChanged<double> onChanged, required void Function(double) onScroll}) {
    return Listener(
      onPointerSignal: (e) { if (e is PointerScrollEvent) onScroll(e.scrollDelta.dy); },
      child: LayoutBuilder(builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => onChanged(min + (d.localPosition.dx / w).clamp(0.0, 1.0) * (max - min)),
          onTapDown: (d) => onChanged(min + (d.localPosition.dx / w).clamp(0.0, 1.0) * (max - min)),
          child: Container(
            height: 18, margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(9), border: Border.all(color: Colors.white24)),
            child: Stack(children: [
              Positioned(
                left: ((value - min) / (max - min) * (w - 14)).clamp(0.0, w - 14), top: 1, bottom: 1,
                child: Container(width: 14, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.black87, width: 2), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3)])),
              ),
            ]),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final curColor = _color;
    final pureHue = HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor();

    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 8), padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.surfaceBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 32, height: 26, decoration: BoxDecoration(color: curColor, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.white38))),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: TextField(
                    controller: _hexController,
                    style: const TextStyle(fontSize: 10, color: Colors.white, fontFamily: 'Consolas'),
                    decoration: InputDecoration(
                      isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      hintText: '#HEX', filled: true, fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.surfaceBorder)),
                    ),
                    onSubmitted: _onHexSubmitted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('🌈 Spectrum (Scroll / Drag)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white70)),
          _buildBar(
            gradient: const LinearGradient(colors: _rainbow), value: _hue, min: 0.0, max: 360.0,
            onChanged: (v) { setState(() { _hue = v; _hexController.text = _toHex(); }); _notify(); },
            onScroll: (dy) { setState(() { _hue = (_hue + (dy > 0 ? 10.0 : -10.0)).clamp(0.0, 360.0); _hexController.text = _toHex(); }); _notify(); },
          ),
          const SizedBox(height: 2),
          const Text('🎨 Shade & Mixer (Dark ↔ Vibrant ↔ Light)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white70)),
          _buildBar(
            gradient: LinearGradient(colors: [Colors.black, pureHue, Colors.white]),
            value: _val < 1.0 ? (_val * 0.5) : (0.5 + (1.0 - _sat) * 0.5), min: 0.0, max: 1.0,
            onChanged: (ratio) {
              setState(() {
                if (ratio <= 0.5) { _val = (ratio * 2.0).clamp(0.05, 1.0); _sat = 1.0; }
                else { _val = 1.0; _sat = (1.0 - (ratio - 0.5) * 2.0).clamp(0.0, 1.0); }
                _hexController.text = _toHex();
              });
              _notify();
            },
            onScroll: (dy) {
              setState(() {
                if (dy > 0) { _val = (_val - 0.05).clamp(0.05, 1.0); }
                else { _sat = (_sat - 0.05).clamp(0.0, 1.0); }
                _hexController.text = _toHex();
              });
              _notify();
            },
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 5, runSpacing: 5,
            children: _swatches.map((c) => GestureDetector(
              onTap: () { setState(() { _syncHsv(c); _hexController.text = _toHex(); }); _notify(); },
              child: Container(width: 17, height: 17, decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: curColor == c ? Colors.amber : Colors.white24, width: curColor == c ? 2 : 1))),
            )).toList(),
          ),
        ],
      ),
    );
  }
}
