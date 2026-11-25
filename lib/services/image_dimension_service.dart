import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import 'video_metadata_service.dart';

class ImageDimensionService {
  static final Map<String, Size> _cache = {};

  static Size? getSize(String path) => _cache[path];

  static Future<Size?> resolve(String path) async {
    if (path.isEmpty || path == 'color_background') return null;
    if (_cache.containsKey(path)) return _cache[path];

    // CRITICAL: Never attempt to decode raw video binaries as still images
    if (AppConstants.isVideoFile(path)) {
      final cached = VideoMetadataService.getCachedDimensions(path);
      if (cached != null) {
        _cache[path] = cached;
        return cached;
      }
      const defaultVideoSize = Size(1920, 1080);
      _cache[path] = defaultVideoSize;
      return defaultVideoSize;
    }

    final file = File(path);
    if (!file.existsSync()) return null;

    try {
      final bytes = await file.readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final size = Size(descriptor.width.toDouble(), descriptor.height.toDouble());
      descriptor.dispose();
      buffer.dispose();
      _cache[path] = size;
      return size;
    } catch (_) {
      return null;
    }
  }

  static void prefetch(List<String> paths) {
    for (final p in paths) {
      if (!AppConstants.isVideoFile(p)) {
        resolve(p);
      }
    }
  }
}
