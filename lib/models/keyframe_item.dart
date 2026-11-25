import 'package:flutter/material.dart';

enum KeyframeEasing {
  linear('Linear', Curves.linear),
  easeIn('Ease In', Curves.easeIn),
  easeOut('Ease Out', Curves.easeOut),
  easeInOut('Ease In-Out', Curves.easeInOut),
  bounceOut('Bounce', Curves.bounceOut),
  elasticOut('Elastic', Curves.elasticOut),
  easeOutBack('Back Out', Curves.easeOutBack);

  final String label;
  final Curve curve;
  const KeyframeEasing(this.label, this.curve);
}

@immutable
class KeyframeItem {
  final double timeFraction; // 0.0 to 1.0
  final double value;
  final KeyframeEasing easing;

  const KeyframeItem({
    required this.timeFraction,
    required this.value,
    this.easing = KeyframeEasing.easeInOut,
  });

  KeyframeItem copyWith({
    double? timeFraction,
    double? value,
    KeyframeEasing? easing,
  }) {
    return KeyframeItem(
      timeFraction: timeFraction ?? this.timeFraction,
      value: value ?? this.value,
      easing: easing ?? this.easing,
    );
  }

  Map<String, dynamic> toJson() => {
        'timeFraction': timeFraction,
        'value': value,
        'easing': easing.name,
      };

  factory KeyframeItem.fromJson(Map<String, dynamic> json) {
    return KeyframeItem(
      timeFraction: (json['timeFraction'] as num).toDouble(),
      value: (json['value'] as num).toDouble(),
      easing: KeyframeEasing.values.firstWhere(
        (e) => e.name == json['easing'],
        orElse: () => KeyframeEasing.easeInOut,
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyframeItem &&
          runtimeType == other.runtimeType &&
          timeFraction == other.timeFraction &&
          value == other.value &&
          easing == other.easing;

  @override
  int get hashCode => Object.hash(timeFraction, value, easing);
}
