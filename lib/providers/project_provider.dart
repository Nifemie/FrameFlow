import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../models/image_item.dart';
import '../models/project.dart';
import '../models/voice_over.dart';
import '../services/timing_engine.dart';

class ProjectNotifier extends StateNotifier<Project> {
  static const _uuid = Uuid();

  ProjectNotifier()
      : super(Project(
          id: _uuid.v4(),
          name: 'Untitled Project',
        ));

  void setProjectName(String name) {
    state = state.copyWith(name: name);
  }

  void addImages(List<String> filePaths) {
    if (filePaths.isEmpty) return;

    final newItems = filePaths.map((path) {
      final fileName = p.basename(path);
      return ImageItem(
        id: _uuid.v4(),
        filePath: path,
        displayName: fileName,
        orderIndex: state.images.length,
      );
    }).toList();

    final combined = [...state.images, ...newItems];
    final calculated = TimingEngine.calculateSequence(
      images: combined,
      voiceOverDurationMs: state.voiceOver?.durationMs,
    );

    state = state.copyWith(images: calculated);
  }

  void removeImage(String id) {
    final filtered = state.images.where((img) => img.id != id).toList();
    final calculated = TimingEngine.calculateSequence(
      images: filtered,
      voiceOverDurationMs: state.voiceOver?.durationMs,
    );
    state = state.copyWith(images: calculated);
  }

  void reorderImages(int oldIndex, int newIndex) {
    final list = List<ImageItem>.from(state.images);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    final calculated = TimingEngine.calculateSequence(
      images: list,
      voiceOverDurationMs: state.voiceOver?.durationMs,
    );
    state = state.copyWith(images: calculated);
  }

  void updateTimestamp(String imageId, String? timestampInput) {
    final updated = TimingEngine.updateImageTimestamp(
      images: state.images,
      imageId: imageId,
      newTimestampInput: timestampInput,
      voiceOverDurationMs: state.voiceOver?.durationMs,
    );
    state = state.copyWith(images: updated);
  }

  void applyBulkTimestamps(List<String> timestampList) {
    final updated = TimingEngine.applyBulkTimestamps(
      images: state.images,
      timestampList: timestampList,
      voiceOverDurationMs: state.voiceOver?.durationMs,
    );
    state = state.copyWith(images: updated);
  }

  String? stampCurrentCutPoint(int currentMs) {
    if (state.images.isEmpty) return null;
    final activeIdx = TimingEngine.findActiveImageIndex(state.images, currentMs);
    if (activeIdx < 0 || activeIdx >= state.images.length) return null;

    final targetItem = state.images[activeIdx];
    // Don't cut if playhead is exactly at startMs
    if (currentMs <= targetItem.startMs) return null;

    final timeStr = (currentMs / 1000).toStringAsFixed(2);
    updateTimestamp(targetItem.id, timeStr);
    return targetItem.displayName;
  }

  void updateFitMode(String imageId, ImageFitMode mode) {
    final updated = state.images.map((img) {
      if (img.id == imageId) return img.copyWith(fitMode: mode);
      return img;
    }).toList();
    state = state.copyWith(images: updated);
  }

  void setVoiceOver(VoiceOver voiceOver) {
    final recalculated = TimingEngine.calculateSequence(
      images: state.images,
      voiceOverDurationMs: voiceOver.durationMs,
    );
    state = state.copyWith(
      voiceOver: voiceOver,
      images: recalculated,
    );
  }

  void removeVoiceOver() {
    final recalculated = TimingEngine.calculateSequence(
      images: state.images,
      voiceOverDurationMs: null,
      snapFinalImageToAudio: false,
    );
    state = state.copyWith(
      clearVoiceOver: true,
      images: recalculated,
    );
  }

  void setAspectRatio(VideoAspectRatio ratio) {
    state = state.copyWith(aspectRatio: ratio);
  }

  void setResolution(VideoResolution res) {
    state = state.copyWith(resolution: res);
  }

  void newProject() {
    state = Project(
      id: _uuid.v4(),
      name: 'Untitled Project',
    );
  }

  void loadProject(Project loaded) {
    state = loaded;
  }
}

final projectProvider =
    StateNotifierProvider<ProjectNotifier, Project>((ref) {
  return ProjectNotifier();
});
