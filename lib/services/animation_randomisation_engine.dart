import 'dart:math';
import '../models/animation_preset.dart';
import '../models/image_item.dart';
import '../models/project.dart';
import '../models/randomisation_config.dart';
import 'animation_library.dart';

class ProposedAssignment {
  final ImageItem asset;
  final AnimationPreset? preset; // null means asset remains unchanged
  final bool isLocked;

  const ProposedAssignment({
    required this.asset,
    required this.preset,
    this.isLocked = false,
  });

  ProposedAssignment copyWith({AnimationPreset? preset, bool? isLocked, bool clearPreset = false}) {
    return ProposedAssignment(
      asset: asset,
      preset: clearPreset ? null : (preset ?? this.preset),
      isLocked: isLocked ?? this.isLocked,
    );
  }
}

class AnimationRandomisationEngine {
  static List<ProposedAssignment> generateAssignments({
    required Project project,
    required RandomisationConfig config,
  }) {
    if (config.selectedPresetIds.isEmpty) return const [];
    final allowedPresets = config.selectedPresetIds
        .map((id) => AnimationLibrary.findById(id))
        .whereType<AnimationPreset>()
        .toList();
    if (allowedPresets.isEmpty) return const [];

    final eligibleAssets = _filterTargetAssets(project, config);
    if (eligibleAssets.isEmpty) return const [];

    final rng = Random(config.seed);
    final results = <ProposedAssignment>[];
    final pool = List<AnimationPreset>.from(allowedPresets);
    final totalEligible = eligibleAssets.length;

    // Calculate exact count of assets to animate based on percentage (1% to 100%)
    final countToAnimate = ((totalEligible * (config.percentage.clamp(0.0, 100.0) / 100.0)).round()).clamp(0, totalEligible);
    final shuffledIndices = List.generate(totalEligible, (i) => i)..shuffle(rng);
    final targetIndices = shuffledIndices.take(countToAnimate).toSet();

    List<AnimationPreset> balancedSequence = [];
    if (config.distributionMode == RandomisationDistributionMode.balanced) {
      while (balancedSequence.length < totalEligible) {
        final shuffled = List<AnimationPreset>.from(pool)..shuffle(rng);
        balancedSequence.addAll(shuffled);
      }
    }

    AnimationPreset? previousPreset;

    for (int i = 0; i < totalEligible; i++) {
      final asset = eligibleAssets[i];
      final lockedAnim = asset.animations.where((a) => a.isLocked).firstOrNull;
      if (lockedAnim != null) {
        final p = AnimationLibrary.findById(lockedAnim.presetId) ?? allowedPresets.first;
        results.add(ProposedAssignment(asset: asset, preset: p, isLocked: true));
        previousPreset = p;
        continue;
      }

      // If not in the percentage target, this asset remains unchanged
      if (!targetIndices.contains(i)) {
        results.add(ProposedAssignment(asset: asset, preset: null, isLocked: false));
        continue;
      }

      AnimationPreset chosen;
      switch (config.distributionMode) {
        case RandomisationDistributionMode.balanced:
          chosen = balancedSequence[i];
          break;

        case RandomisationDistributionMode.noImmediateRepetition:
          if (pool.length > 1 && previousPreset != null) {
            final candidates = pool.where((p) => p.id != previousPreset!.id).toList();
            chosen = candidates[rng.nextInt(candidates.length)];
          } else {
            chosen = pool[rng.nextInt(pool.length)];
          }
          break;

        case RandomisationDistributionMode.completelyRandom:
          chosen = pool[rng.nextInt(pool.length)];
          break;
      }

      results.add(ProposedAssignment(asset: asset, preset: chosen));
      previousPreset = chosen;
    }

    return results;
  }

  static List<ImageItem> _filterTargetAssets(Project project, RandomisationConfig config) {
    switch (config.targetScope) {
      case RandomisationTargetScope.allImages:
        return project.images.where((img) => !img.isColorBackground).toList();
      case RandomisationTargetScope.selectedTrack:
        final tid = config.trackId ?? 'track_v1';
        return project.images.where((img) => img.trackId == tid && !img.isColorBackground).toList();
      case RandomisationTargetScope.selectedAssets:
        return project.images.where((img) => config.selectedAssetIds.contains(img.id)).toList();
      case RandomisationTargetScope.timelineRange:
        return project.images.where((img) => img.startMs < config.rangeEndMs && img.endMs > config.rangeStartMs && !img.isColorBackground).toList();
    }
  }

  static Project applyAssignments({
    required Project project,
    required List<ProposedAssignment> assignments,
    int durationMs = 600,
  }) {
    final map = {for (final a in assignments) a.asset.id: a};
    final updatedImages = project.images.map((img) {
      final assignment = map[img.id];
      if (assignment == null || assignment.preset == null) return img; // Remains unchanged

      final newAnim = assignment.preset!.toAssetAnimation(
        durationMs: durationMs,
        isLocked: assignment.isLocked,
      );

      final preservedLocked = img.animations.where((a) => a.isLocked && a.presetId != newAnim.presetId).toList();
      return img.copyWith(animations: [...preservedLocked, newAnim]);
    }).toList();

    return project.copyWith(images: updatedImages);
  }
}
