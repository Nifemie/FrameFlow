import '../models/asset_transform.dart';
import '../models/image_item.dart';

enum AlignmentType {
  left,
  horizontalCenter,
  right,
  top,
  verticalCenter,
  bottom,
  centerCanvas,
  distributeHorizontal,
  distributeVertical,
  matchWidth,
  matchHeight,
}

/// Comprehensive Alignment & Distribution Service for visual assets.
class AlignmentService {
  /// Aligns a single asset on canvas coordinates.
  static AssetTransform alignSingle(AssetTransform t, AlignmentType type) {
    switch (type) {
      case AlignmentType.left:
        return t.copyWith(positionX: -0.75);
      case AlignmentType.horizontalCenter:
        return t.copyWith(positionX: 0.0);
      case AlignmentType.right:
        return t.copyWith(positionX: 0.75);
      case AlignmentType.top:
        return t.copyWith(positionY: -0.75);
      case AlignmentType.verticalCenter:
        return t.copyWith(positionY: 0.0);
      case AlignmentType.bottom:
        return t.copyWith(positionY: 0.75);
      case AlignmentType.centerCanvas:
        return t.copyWith(positionX: 0.0, positionY: 0.0);
      case AlignmentType.matchWidth:
        return t.copyWith(scaleX: 1.0);
      case AlignmentType.matchHeight:
        return t.copyWith(scaleY: 1.0);
      case AlignmentType.distributeHorizontal:
      case AlignmentType.distributeVertical:
        return t;
    }
  }

  /// Aligns multiple selected visual items relative to each other or canvas.
  static List<ImageItem> alignMultiple({
    required List<ImageItem> allImages,
    required Set<String> targetIds,
    required AlignmentType type,
  }) {
    if (targetIds.isEmpty) return allImages;
    final selected = allImages.where((i) => targetIds.contains(i.id)).toList();
    if (selected.isEmpty) return allImages;

    // Single item fallback to canvas alignment
    if (selected.length == 1) {
      final target = selected.first;
      final newT = alignSingle(target.transform, type);
      return allImages.map((i) => i.id == target.id ? i.copyWith(transform: newT) : i).toList();
    }

    final minX = selected.map((i) => i.transform.positionX).reduce((a, b) => a < b ? a : b);
    final maxX = selected.map((i) => i.transform.positionX).reduce((a, b) => a > b ? a : b);
    final minY = selected.map((i) => i.transform.positionY).reduce((a, b) => a < b ? a : b);
    final maxY = selected.map((i) => i.transform.positionY).reduce((a, b) => a > b ? a : b);
    final avgX = selected.map((i) => i.transform.positionX).reduce((a, b) => a + b) / selected.length;
    final avgY = selected.map((i) => i.transform.positionY).reduce((a, b) => a + b) / selected.length;
    final primaryScaleX = selected.first.transform.scaleX;
    final primaryScaleY = selected.first.transform.scaleY;

    final updated = <ImageItem>[];
    for (final item in allImages) {
      if (!targetIds.contains(item.id)) {
        updated.add(item);
        continue;
      }

      AssetTransform newT = item.transform;
      switch (type) {
        case AlignmentType.left:
          newT = newT.copyWith(positionX: minX);
          break;
        case AlignmentType.horizontalCenter:
          newT = newT.copyWith(positionX: avgX);
          break;
        case AlignmentType.right:
          newT = newT.copyWith(positionX: maxX);
          break;
        case AlignmentType.top:
          newT = newT.copyWith(positionY: minY);
          break;
        case AlignmentType.verticalCenter:
          newT = newT.copyWith(positionY: avgY);
          break;
        case AlignmentType.bottom:
          newT = newT.copyWith(positionY: maxY);
          break;
        case AlignmentType.centerCanvas:
          newT = newT.copyWith(positionX: 0.0, positionY: 0.0);
          break;
        case AlignmentType.matchWidth:
          newT = newT.copyWith(scaleX: primaryScaleX);
          break;
        case AlignmentType.matchHeight:
          newT = newT.copyWith(scaleY: primaryScaleY);
          break;
        case AlignmentType.distributeHorizontal:
          if (selected.length > 2) {
            final sorted = List<ImageItem>.from(selected)..sort((a, b) => a.transform.positionX.compareTo(b.transform.positionX));
            final rank = sorted.indexWhere((s) => s.id == item.id);
            final step = (maxX - minX) / (selected.length - 1);
            newT = newT.copyWith(positionX: minX + (step * rank));
          }
          break;
        case AlignmentType.distributeVertical:
          if (selected.length > 2) {
            final sorted = List<ImageItem>.from(selected)..sort((a, b) => a.transform.positionY.compareTo(b.transform.positionY));
            final rank = sorted.indexWhere((s) => s.id == item.id);
            final step = (maxY - minY) / (selected.length - 1);
            newT = newT.copyWith(positionY: minY + (step * rank));
          }
          break;
      }
      updated.add(item.copyWith(transform: newT));
    }
    return updated;
  }
}
