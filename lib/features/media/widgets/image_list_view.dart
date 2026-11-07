import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/natural_sort.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../timestamps/widgets/bulk_timestamp_dialog.dart';
import 'image_card.dart';

class ImageListView extends ConsumerWidget {
  const ImageListView({super.key});

  Future<void> _pickImages(WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.supportedImageExtensions,
      allowMultiple: true,
    );

    if (result != null) {
      final paths = result.paths.whereType<String>().toList();
      _addPaths(ref, paths);
    }
  }

  Future<void> _pickFolder(WidgetRef ref) async {
    final folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath == null) return;

    final dir = Directory(folderPath);
    if (!await dir.exists()) return;

    final imageFiles = <String>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase().replaceAll('.', '');
        if (AppConstants.supportedImageExtensions.contains(ext)) {
          imageFiles.add(entity.path);
        }
      }
    }

    imageFiles.sort((a, b) => NaturalSort.compare(p.basename(a), p.basename(b)));
    _addPaths(ref, imageFiles);
  }

  void _addPaths(WidgetRef ref, List<String> paths) {
    if (paths.isEmpty) return;
    ref.read(projectProvider.notifier).addImages(paths);
    if (ref.read(selectedImageIdProvider) == null) {
      final images = ref.read(projectProvider).images;
      if (images.isNotEmpty) {
        ref.read(selectedImageIdProvider.notifier).state = images.first.id;
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = ref.watch(projectProvider.select((p) => p.images));
    final selectedId = ref.watch(selectedImageIdProvider);

    return Column(
      children: [
        // Action header with Add, Folder, and Bulk buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Images (${images.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.playlist_add_check, size: 18, color: AppColors.clipBlueLight),
                    tooltip: 'Bulk paste timestamps or CSV',
                    splashRadius: 16,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const BulkTimestampDialog(),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.folder_open, size: 18, color: AppColors.clipBlueLight),
                    tooltip: 'Import folder of images',
                    splashRadius: 16,
                    onPressed: () => _pickFolder(ref),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.clipBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: () => _pickImages(ref),
                    icon: const Icon(Icons.add_photo_alternate, size: 14),
                    label: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // List or Empty Placeholder
        Expanded(
          child: images.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_library_outlined,
                          size: 36, color: AppColors.textMuted.withValues(alpha: 0.6)),
                      const SizedBox(height: 8),
                      const Text(
                        'No images yet',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Click Add or Folder icon above',
                        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: images.length,
                  onReorder: (oldIdx, newIdx) {
                    ref.read(projectProvider.notifier).reorderImages(oldIdx, newIdx);
                  },
                  itemBuilder: (context, index) {
                    final item = images[index];
                    return ImageCard(
                      key: ValueKey(item.id),
                      item: item,
                      isSelected: item.id == selectedId,
                      onSelect: () {
                        ref.read(selectedImageIdProvider.notifier).state = item.id;
                        ref.read(playheadPositionProvider.notifier).state = item.startMs;
                      },
                      onDelete: () {
                        ref.read(projectProvider.notifier).removeImage(item.id);
                        if (selectedId == item.id) {
                          ref.read(selectedImageIdProvider.notifier).state = null;
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
