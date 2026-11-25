import 'package:flutter/foundation.dart';

enum RandomisationTargetScope {
  allImages('All Images in Project'),
  selectedTrack('All Assets on Track'),
  selectedAssets('Only Selected Assets'),
  timelineRange('Assets in Timeline Range');

  final String label;
  const RandomisationTargetScope(this.label);
}

enum RandomisationDistributionMode {
  balanced('Balanced Distribution'),
  noImmediateRepetition('No Immediate Repetition'),
  completelyRandom('Completely Random');

  final String label;
  const RandomisationDistributionMode(this.label);
}

@immutable
class RandomisationConfig {
  final Set<String> selectedPresetIds;
  final RandomisationTargetScope targetScope;
  final String? trackId;
  final Set<String> selectedAssetIds;
  final int rangeStartMs;
  final int rangeEndMs;
  final double percentage; // 0.0 to 100.0
  final RandomisationDistributionMode distributionMode;
  final int seed;
  final int defaultDurationMs;

  const RandomisationConfig({
    this.selectedPresetIds = const {},
    this.targetScope = RandomisationTargetScope.allImages,
    this.trackId,
    this.selectedAssetIds = const {},
    this.rangeStartMs = 0,
    this.rangeEndMs = 60000,
    this.percentage = 100.0,
    this.distributionMode = RandomisationDistributionMode.balanced,
    this.seed = 42,
    this.defaultDurationMs = 600,
  });

  RandomisationConfig copyWith({
    Set<String>? selectedPresetIds,
    RandomisationTargetScope? targetScope,
    String? trackId,
    Set<String>? selectedAssetIds,
    int? rangeStartMs,
    int? rangeEndMs,
    double? percentage,
    RandomisationDistributionMode? distributionMode,
    int? seed,
    int? defaultDurationMs,
  }) {
    return RandomisationConfig(
      selectedPresetIds: selectedPresetIds ?? this.selectedPresetIds,
      targetScope: targetScope ?? this.targetScope,
      trackId: trackId ?? this.trackId,
      selectedAssetIds: selectedAssetIds ?? this.selectedAssetIds,
      rangeStartMs: rangeStartMs ?? this.rangeStartMs,
      rangeEndMs: rangeEndMs ?? this.rangeEndMs,
      percentage: percentage ?? this.percentage,
      distributionMode: distributionMode ?? this.distributionMode,
      seed: seed ?? this.seed,
      defaultDurationMs: defaultDurationMs ?? this.defaultDurationMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'selectedPresetIds': selectedPresetIds.toList(),
        'targetScope': targetScope.name,
        'trackId': trackId,
        'selectedAssetIds': selectedAssetIds.toList(),
        'rangeStartMs': rangeStartMs,
        'rangeEndMs': rangeEndMs,
        'percentage': percentage,
        'distributionMode': distributionMode.name,
        'seed': seed,
        'defaultDurationMs': defaultDurationMs,
      };

  factory RandomisationConfig.fromJson(Map<String, dynamic> json) {
    return RandomisationConfig(
      selectedPresetIds: Set<String>.from(json['selectedPresetIds'] as List<dynamic>? ?? []),
      targetScope: RandomisationTargetScope.values.firstWhere(
        (t) => t.name == json['targetScope'],
        orElse: () => RandomisationTargetScope.allImages,
      ),
      trackId: json['trackId'] as String?,
      selectedAssetIds: Set<String>.from(json['selectedAssetIds'] as List<dynamic>? ?? []),
      rangeStartMs: json['rangeStartMs'] as int? ?? 0,
      rangeEndMs: json['rangeEndMs'] as int? ?? 60000,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 100.0,
      distributionMode: RandomisationDistributionMode.values.firstWhere(
        (d) => d.name == json['distributionMode'],
        orElse: () => RandomisationDistributionMode.balanced,
      ),
      seed: json['seed'] as int? ?? 42,
      defaultDurationMs: json['defaultDurationMs'] as int? ?? 600,
    );
  }
}
