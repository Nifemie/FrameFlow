import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../models/image_item.dart';
import '../models/project.dart';
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
      'fps': project.fps,
      'scriptText': project.scriptText,
      'voiceOver': project.voiceOver == null
          ? null
          : {
              'filePath': project.voiceOver!.filePath,
              'fileName': project.voiceOver!.fileName,
              'durationMs': project.voiceOver!.durationMs,
            },
      'images': project.images.map((img) => {
        'id': img.id,
        'filePath': img.filePath,
        'displayName': img.displayName,
        'orderIndex': img.orderIndex,
        'userEndTimestampInput': img.userEndTimestampInput,
        'fitMode': img.fitMode.name,
      }).toList(),
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

      return ImageItem(
        id: imgMap['id'] as String,
        filePath: imgMap['filePath'] as String,
        displayName: imgMap['displayName'] as String,
        orderIndex: imgMap['orderIndex'] as int,
        userEndTimestampInput: imgMap['userEndTimestampInput'] as String?,
        fitMode: fit,
      );
    }).toList();

    final calculated = TimingEngine.calculateSequence(
      images: rawImages,
      voiceOverDurationMs: voiceOver?.durationMs,
    );

    return Project(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Untitled Project',
      images: calculated,
      voiceOver: voiceOver,
      scriptText: map['scriptText'] as String?,
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

  /// Saves autosave recovery state to app documents directory.
  static Future<void> saveAutosave(Project project) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/frameflow_autosave.json');
      final jsonStr = jsonEncode(projectToMap(project));
      await file.writeAsString(jsonStr);
    } catch (_) {}
  }
}
