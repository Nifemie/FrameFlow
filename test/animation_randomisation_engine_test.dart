import 'package:flutter_test/flutter_test.dart';
import 'package:frameflow/models/image_item.dart';
import 'package:frameflow/models/project.dart';
import 'package:frameflow/models/randomisation_config.dart';
import 'package:frameflow/services/animation_library.dart';
import 'package:frameflow/services/animation_randomisation_engine.dart';

void main() {
  group('AnimationRandomisationEngine Tests', () {
    late Project testProject;

    setUp(() {
      final images = List.generate(
        10,
        (i) => ImageItem(
          id: 'img_$i',
          filePath: 'C:/assets/img_$i.jpg',
          displayName: 'img_$i.jpg',
          orderIndex: i,
          startMs: i * 3000,
          endMs: (i + 1) * 3000,
          durationMs: 3000,
        ),
      );
      testProject = Project(id: 'p1', name: 'Test', images: images);
    });

    test('Strict whitelist: never assigns unselected animations', () {
      final allowed = {'zoomIn', 'slideInLeft'};
      final config = RandomisationConfig(
        selectedPresetIds: allowed,
        distributionMode: RandomisationDistributionMode.completelyRandom,
        seed: 12345,
      );

      final assignments = AnimationRandomisationEngine.generateAssignments(
        project: testProject,
        config: config,
      );

      expect(assignments.length, 10);
      for (final a in assignments) {
        expect(allowed.contains(a.preset?.id), isTrue);
      }
    });

    test('Percentage coverage: 50% animates exactly half and leaves other half null', () {
      final config = const RandomisationConfig(
        selectedPresetIds: {'zoomIn', 'fadeIn'},
        percentage: 50.0,
        seed: 12345,
      );

      final assignments = AnimationRandomisationEngine.generateAssignments(
        project: testProject,
        config: config,
      );

      expect(assignments.length, 10);
      final animated = assignments.where((a) => a.preset != null).toList();
      final unchanged = assignments.where((a) => a.preset == null).toList();
      expect(animated.length, 5);
      expect(unchanged.length, 5);

      final updatedProject = AnimationRandomisationEngine.applyAssignments(
        project: testProject,
        assignments: assignments,
      );
      final updatedAnimated = updatedProject.images.where((img) => img.animations.isNotEmpty).toList();
      final updatedUntouched = updatedProject.images.where((img) => img.animations.isEmpty).toList();
      expect(updatedAnimated.length, 5);
      expect(updatedUntouched.length, 5);
    });

    test('Seed reproducibility: identical seed produces identical results', () {
      final config1 = const RandomisationConfig(
        selectedPresetIds: {'zoomIn', 'fadeIn', 'bounceIn', 'slideInTop'},
        seed: 9999,
      );
      final config2 = const RandomisationConfig(
        selectedPresetIds: {'zoomIn', 'fadeIn', 'bounceIn', 'slideInTop'},
        seed: 9999,
      );

      final res1 = AnimationRandomisationEngine.generateAssignments(project: testProject, config: config1);
      final res2 = AnimationRandomisationEngine.generateAssignments(project: testProject, config: config2);

      for (int i = 0; i < res1.length; i++) {
        expect(res1[i].preset?.id, equals(res2[i].preset?.id));
      }
    });

    test('No immediate repetition avoids identical adjacent presets', () {
      final config = const RandomisationConfig(
        selectedPresetIds: {'zoomIn', 'fadeIn', 'slideInLeft', 'bounceIn'},
        distributionMode: RandomisationDistributionMode.noImmediateRepetition,
        seed: 777,
      );

      final assignments = AnimationRandomisationEngine.generateAssignments(
        project: testProject,
        config: config,
      );

      for (int i = 1; i < assignments.length; i++) {
        expect(assignments[i].preset?.id, isNot(equals(assignments[i - 1].preset?.id)));
      }
    });

    test('Timeline range filtering only targets assets inside range', () {
      final config = const RandomisationConfig(
        selectedPresetIds: {'zoomIn'},
        targetScope: RandomisationTargetScope.timelineRange,
        rangeStartMs: 3000,
        rangeEndMs: 9000, // covers img_1 and img_2
      );

      final assignments = AnimationRandomisationEngine.generateAssignments(
        project: testProject,
        config: config,
      );

      expect(assignments.length, 2);
      expect(assignments.map((a) => a.asset.id), containsAll(['img_1', 'img_2']));
    });

    test('Preserves locked animations during randomisation', () {
      final lockedAnim = AnimationLibrary.findById('rotateIn')!.toAssetAnimation(isLocked: true);
      final modifiedImages = List<ImageItem>.from(testProject.images);
      modifiedImages[0] = modifiedImages[0].copyWith(animations: [lockedAnim]);
      final proj = testProject.copyWith(images: modifiedImages);

      final config = const RandomisationConfig(
        selectedPresetIds: {'zoomIn', 'fadeIn'},
        seed: 42,
      );

      final assignments = AnimationRandomisationEngine.generateAssignments(
        project: proj,
        config: config,
      );

      expect(assignments[0].preset?.id, 'rotateIn');
      expect(assignments[0].isLocked, isTrue);
    });
  });
}
