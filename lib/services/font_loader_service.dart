import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class FontLoaderService {
  static final Set<String> _loadedFamilies = {};

  static const List<String> presetFontFamilies = [
    'Roboto',
    'Montserrat',
    'Bebas Neue',
    'Impact',
    'Arial',
    'Times New Roman',
    'Courier New',
    'Georgia',
  ];

  static Future<String?> loadCustomFont(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final ext = p.extension(filePath).toLowerCase();
    if (ext != '.ttf' && ext != '.otf') return null;

    final familyName = p.basenameWithoutExtension(filePath).replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    if (_loadedFamilies.contains(familyName)) return familyName;

    try {
      final bytes = await file.readAsBytes();
      final fontData = ByteData.view(bytes.buffer);
      final loader = FontLoader(familyName);
      loader.addFont(Future.value(fontData));
      await loader.load();
      _loadedFamilies.add(familyName);
      return familyName;
    } catch (_) {
      return null;
    }
  }

  static bool isFontLoaded(String familyName) => _loadedFamilies.contains(familyName);
}
