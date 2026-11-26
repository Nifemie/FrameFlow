import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/image_item.dart';
import '../../../models/timeline_track_item.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../timeline/widgets/asset_context_menus.dart';
import '../../timestamps/widgets/bulk_timestamp_dialog.dart';
import 'folder_import_dialog.dart';
import 'image_card.dart';

class ImageListView extends ConsumerStatefulWidget {
  const ImageListView({super.key});

  @override
  ConsumerState<ImageListView> createState() => _ImageListViewState();
}

class _ImageListViewState extends ConsumerState<ImageListView> {
  String _targetTrack = 'track_v1';

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        ...AppConstants.supportedVideoExtensions,
        ...AppConstants.supportedImageExtensions,
      ],
      allowMultiple: true,
    );
    if (result != null) _addPaths(result.paths.whereType<String>().toList());
  }

  Future<void> _pickFolder() async {
    final folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath == null || !mounted) return;
    showDialog(context: context, builder: (_) => FolderImportDialog(directoryPath: folderPath, onImportConfirmed: (paths, stamps) => _addPaths(paths, stamps)));
  }

  void _addPaths(List<String> paths, [List<String>? timestamps]) {
    if (paths.isEmpty) return;
    final targetTrack = _targetTrack == 'all' ? 'track_v1' : _targetTrack;
    final playheadMs = ref.read(playheadPositionProvider);
    ref.read(projectProvider.notifier).addImages(paths, trackId: targetTrack, insertAtMs: playheadMs);
    if (timestamps != null && timestamps.isNotEmpty) ref.read(projectProvider.notifier).applyBulkTimestamps(timestamps, trackId: targetTrack);
    if (ref.read(selectedImageIdProvider) == null) {
      final images = ref.read(projectProvider).images;
      if (images.isNotEmpty) ref.read(selectedImageIdProvider.notifier).state = images.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(projectProvider);
    final allImages = project.images;
    final selectedId = ref.watch(selectedImageIdProvider);
    final videoTracks = project.effectiveTracks.where((t) => t.isVideoOrBg).toList();
    final displayedImages = _targetTrack == 'all' ? allImages : allImages.where((i) => i.trackId == _targetTrack).toList();

    Color btnColor = _targetTrack == 'track_bg' ? Colors.purpleAccent : AppColors.accentOrange;
    final activeTrack = videoTracks.where((t) => t.id == _targetTrack).firstOrNull;
    if (activeTrack != null && activeTrack.type == TrackType.overlayVideo) btnColor = Colors.cyanAccent;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Clips (${allImages.length})',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.palette_outlined, size: 16, color: Colors.purpleAccent),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Add Color Matte to ${_targetTrack == "track_bg" ? "Underlay Track" : "Selected Track"}', splashRadius: 14,
                    onPressed: () => ref.read(projectProvider.notifier).addColorBackground(trackId: _targetTrack == 'all' ? 'track_v1' : _targetTrack),
                  ),
                  IconButton(
                    icon: const Icon(Icons.playlist_add_check, size: 16, color: AppColors.accentOrange),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Bulk paste timestamps or CSV', splashRadius: 14,
                    onPressed: () => showDialog(context: context, builder: (_) => const BulkTimestampDialog()),
                  ),
                  IconButton(
                    icon: const Icon(Icons.folder_open, size: 16, color: AppColors.accentOrange),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    tooltip: 'Import folder of images', splashRadius: 14,
                    onPressed: _pickFolder,
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: btnColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      minimumSize: const Size(0, 28),
                      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    onPressed: _pickImages,
                    icon: const Icon(Icons.add_photo_alternate, size: 13),
                    label: Text(activeTrack != null && activeTrack.type == TrackType.overlayVideo ? 'Add (V2)' : 'Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final tr in videoTracks) ...[
                  _buildFilterChip(
                    tr.id,
                    '${tr.name.split(' ').first} (${allImages.where((i) => i.trackId == tr.id).length})',
                    tr.type == TrackType.overlayVideo ? Colors.cyanAccent : (tr.type == TrackType.backgroundUnderlay ? Colors.purpleAccent : AppColors.accentOrange),
                  ),
                  const SizedBox(width: 4),
                ],
                _buildFilterChip('all', 'All (${allImages.length})', AppColors.textMuted),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.surfaceBorder),
        Expanded(
          child: displayedImages.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 28, color: AppColors.textMuted.withValues(alpha: 0.5)),
                        const SizedBox(height: 6),
                        Text(_targetTrack == 'track_bg' ? 'No Underlay Clips' : 'No Clips in Selected Track', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: btnColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                          onPressed: _pickImages, icon: const Icon(Icons.add_photo_alternate, size: 12),
                          label: const Text('Add Images to Track', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.all(8),
                  itemCount: displayedImages.length,
                  onReorder: (oldIndex, newIndex) {
                    final item = displayedImages[oldIndex];
                    final rawOld = allImages.indexOf(item);
                    final rawNew = newIndex >= displayedImages.length
                        ? allImages.length
                        : allImages.indexOf(displayedImages[newIndex]);
                    if (rawOld >= 0 && rawNew >= 0) ref.read(projectProvider.notifier).reorderImages(rawOld, rawNew);
                  },
                  itemBuilder: (context, index) {
                    final item = displayedImages[index];
                    return DragTarget<ImageItem>(
                      key: ValueKey(item.id),
                      onWillAcceptWithDetails: (details) => details.data.id != item.id,
                      onAcceptWithDetails: (details) {
                        final draggedIdx = displayedImages.indexWhere((i) => i.id == details.data.id);
                        final insertBefore = draggedIdx < 0 || draggedIdx > index;
                        ref.read(projectProvider.notifier).reorderAndOccupy(
                          details.data.id,
                          item.id,
                          insertBefore: insertBefore,
                        );
                      },
                      builder: (context, candidateData, _) {
                        final isDropHover = candidateData.isNotEmpty;
                        return Container(
                          decoration: isDropHover
                              ? BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: AppColors.accentOrange, width: 2),
                                  ),
                                )
                              : null,
                          child: Draggable<ImageItem>(
                            data: item,
                            feedback: Material(
                              color: Colors.transparent,
                              child: Opacity(
                                opacity: 0.85,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.accentOrange, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accentOrange.withValues(alpha: 0.35),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(item.isVideo ? Icons.videocam_rounded : Icons.image_rounded, size: 14, color: AppColors.accentOrange),
                                      const SizedBox(width: 6),
                                      Text(item.displayName, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            child: GestureDetector(
                              onSecondaryTapUp: (details) => AssetContextMenus.showMediaClipMenu(
                                context: context,
                                ref: ref,
                                globalPosition: details.globalPosition,
                                item: item,
                              ),
                              child: ImageCard(
                                item: item,
                                isSelected: item.id == selectedId,
                                onTap: () => SelectionHelper.selectImage(ref, item.id),
                                onRemove: () {
                                  ref.read(projectProvider.notifier).removeImage(item.id);
                                  if (selectedId == item.id) SelectionHelper.clearAll(ref);
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String trackKey, String label, Color accentColor) {
    final isSelected = _targetTrack == trackKey;
    return InkWell(
      onTap: () => setState(() => _targetTrack = trackKey),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? accentColor : AppColors.surfaceBorder, width: isSelected ? 1.0 : 0.6),
        ),
        child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : AppColors.textMuted)),
      ),
    );
  }
}
