import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../models/asset_animation.dart';
import '../models/asset_transform.dart';
import '../models/audio_clip_item.dart';
import '../models/image_item.dart';
import '../models/project.dart';
import '../models/text_overlay_item.dart';
import '../models/voice_over.dart';
import 'timing_engine.dart';

class ProjectStorageService {
  /// Converts a Project instance into a JSON-encodable Map.
  static Map<String, dynamic> projectToMap(Project project) {
    return {
      'id': project.id,
      'name': project.name,
      'aspectRatio': project.aspectRatio.name,
      'resolution': project.resolution.name,
      'timingMode': project.timingMode.name,
      'fps': project.fps,
      'scriptText': project.scriptText,
      'voiceOver': project.voiceOver == null
          ? null
          : {
              'filePath': project.voiceOver!.filePath,
              'fileName': project.voiceOver!.fileName,
              'durationMs': project.voiceOver!.durationMs,
            },
      'audioClips': project.audioClips.map((c) => {
        'id': c.id,
        'filePath': c.filePath,
        'fileName': c.fileName,
        'startTimelineMs': c.startTimelineMs,
        'durationMs': c.durationMs,
        'volume': c.volume,
        'orderIndex': c.orderIndex,
      }).toList(),
      'images': project.images.map((img) => {
        'id': img.id, 'filePath': img.filePath, 'displayName': img.displayName,
        'orderIndex': img.orderIndex, 'userStartTimestampInput': img.userStartTimestampInput,
        'userEndTimestampInput': img.userEndTimestampInput, 'fitMode': img.fitMode.name,
        'backgroundColorValue': img.backgroundColorValue, 'trackId': img.trackId,
        'sourceStartOffsetMs': img.sourceStartOffsetMs,
        'sourceDurationMs': img.sourceDurationMs,
        'transform': img.transform.toJson(),
        'animations': img.animations.map((a) => a.toJson()).toList(),
      }).toList(),
      'textOverlays': project.textOverlays.map((t) => t.toJson()).toList(),
    };
  }

  /// Deserializes a Map into a Project instance and recalibrates the sequence.
  static Project projectFromMap(Map<String, dynamic> map) {
    final ratio = VideoAspectRatio.values.firstWhere(
      (r) => r.name == map['aspectRatio'],
      orElse: () => VideoAspectRatio.ratio16x9,
    );
    final res = VideoResolution.values.firstWhere(
      (r) => r.name == map['resolution'],
      orElse: () => VideoResolution.res1080p,
    );
    final timingMode = TimingMode.values.firstWhere(
      (t) => t.name == map['timingMode'],
      orElse: () => TimingMode.automatic,
    );

    VoiceOver? voiceOver;
    if (map['voiceOver'] != null) {
      final voMap = map['voiceOver'] as Map<String, dynamic>;
      voiceOver = VoiceOver(
        filePath: voMap['filePath'] as String,
        fileName: voMap['fileName'] as String,
        durationMs: voMap['durationMs'] as int,
      );
    }

    final rawImages = (map['images'] as List<dynamic>? ?? []).map((item) {
      final imgMap = item as Map<String, dynamic>;
      final fit = ImageFitMode.values.firstWhere(
        (f) => f.name == imgMap['fitMode'],
        orElse: () => ImageFitMode.fit,
      );

      final anims = (imgMap['animations'] as List<dynamic>? ?? [])
          .map((a) => AssetAnimation.fromJson(a as Map<String, dynamic>))
          .toList();
      final transform = imgMap['transform'] != null
          ? AssetTransform.fromJson(imgMap['transform'] as Map<String, dynamic>)
          : AssetTransform.identity;

      return ImageItem(
        id: imgMap['id'] as String,
        filePath: imgMap['filePath'] as String,
        displayName: imgMap['displayName'] as String,
        orderIndex: imgMap['orderIndex'] as int,
        userStartTimestampInput: imgMap['userStartTimestampInput'] as String?,
        userEndTimestampInput: imgMap['userEndTimestampInput'] as String?,
        fitMode: fit,
        backgroundColorValue: imgMap['backgroundColorValue'] as int?,
        trackId: imgMap['trackId'] as String? ?? 'track_v1',
        sourceStartOffsetMs: imgMap['sourceStartOffsetMs'] as int? ?? 0,
        sourceDurationMs: imgMap['sourceDurationMs'] as int?,
        transform: transform,
        animations: anims,
      );
    }).toList();

    final calculated = TimingEngine.calculateSequence(
      images: rawImages,
      voiceOverDurationMs: voiceOver?.durationMs,
    );

    final audioClips = (map['audioClips'] as List<dynamic>? ?? []).map((c) {
      final cm = c as Map<String, dynamic>;
      return AudioClipItem(
        id: cm['id'] as String,
        filePath: cm['filePath'] as String,
        fileName: cm['fileName'] as String,
        startTimelineMs: cm['startTimelineMs'] as int,
        durationMs: cm['durationMs'] as int,
        volume: (cm['volume'] as num?)?.toDouble() ?? 1.0,
        orderIndex: cm['orderIndex'] as int,
      );
    }).toList();

    final textOverlays = (map['textOverlays'] as List<dynamic>? ?? []).map((t) {
      return TextOverlayItem.fromJson(t as Map<String, dynamic>);
    }).toList();

    return Project(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Untitled Project',
      images: calculated,
      voiceOver: voiceOver,
      audioClips: audioClips,
      textOverlays: textOverlays,
      scriptText: map['scriptText'] as String?,
      timingMode: timingMode,
      aspectRatio: ratio,
      resolution: res,
      fps: map['fps'] as int? ?? 30,
    );
  }

  /// Saves a project to a `.frameflow` file.
  static Future<void> saveProject(Project project, String filePath) async {
    final validPath = filePath.endsWith('.frameflow') ? filePath : '$filePath.frameflow';
    final file = File(validPath);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(projectToMap(project));
    await file.writeAsString(jsonStr);
  }

  /// Loads a project from a `.frameflow` file.
  static Future<Project> loadProject(String filePath) async {
    final file = File(filePath);
    final jsonStr = await file.readAsString();
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return projectFromMap(map);
  }

  /// Gets the File handle for the autosave cache.
  static Future<File> getAutosaveFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/frameflow_autosave.json');
  }

  /// Checks if an autosave recovery file exists.
  static Future<bool> hasAutosave() async {
    try {
      final file = await getAutosaveFile();
      return file.existsSync() && (await file.length()) > 0;
    } catch (_) {
      return false;
    }
  }

  /// Loads the autosaved project, if present.
  static Future<Project?> loadAutosave() async {
    try {
      final file = await getAutosaveFile();
      if (!file.existsSync()) return null;
      final jsonStr = await file.readAsString();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return projectFromMap(map);
    } catch (_) {
      return null;
    }
  }

  /// Deletes the autosave cache file.
  static Future<void> clearAutosave() async {
    try {
      final file = await getAutosaveFile();
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Saves autosave recovery state to app documents directory.
  static Future<void> saveAutosave(Project project) async {
    try {
      final file = await getAutosaveFile();
      final jsonStr = jsonEncode(projectToMap(project));
      await file.writeAsString(jsonStr);
    } catch (_) {}
  }
}
