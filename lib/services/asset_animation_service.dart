import '../models/asset_animation.dart';
import '../models/asset_transform.dart';
import '../models/project.dart';
import 'animation_randomisation_engine.dart';

class AssetAnimationService {
  static Project updateTransform(Project project, String imageId, AssetTransform transform) {
    final updated = project.images.map((img) => img.id == imageId ? img.copyWith(transform: transform) : img).toList();
    return project.copyWith(images: updated);
  }

  static Project addAnimation(Project project, String imageId, AssetAnimation animation) {
    final updated = project.images.map((img) {
      if (img.id != imageId) return img;
      // If adding an entrance or exit preset, replace existing preset of the same category
      final filtered = img.animations.where((a) => a.category != animation.category).toList();
      return img.copyWith(animations: [...filtered, animation]);
    }).toList();
    return project.copyWith(images: updated);
  }

  static Project removeAnimation(Project project, String imageId, String animationId) {
    final updated = project.images.map((img) {
      if (img.id != imageId) return img;
      return img.copyWith(animations: img.animations.where((a) => a.id != animationId).toList());
    }).toList();
    return project.copyWith(images: updated);
  }

  static Project updateAnimation(Project project, String imageId, AssetAnimation animation) {
    final updated = project.images.map((img) {
      if (img.id != imageId) return img;
      return img.copyWith(animations: img.animations.map((a) => a.id == animation.id ? animation : a).toList());
    }).toList();
    return project.copyWith(images: updated);
  }

  static Project clearAnimations(Project project, String imageId) {
    final updated = project.images.map((img) => img.id == imageId ? img.copyWith(animations: const []) : img).toList();
    return project.copyWith(images: updated);
  }

  static Project applyRandomisation(Project project, List<ProposedAssignment> assignments, {int durationMs = 600}) {
    return AnimationRandomisationEngine.applyAssignments(project: project, assignments: assignments, durationMs: durationMs);
  }
}
