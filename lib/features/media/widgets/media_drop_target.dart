import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MediaDropTarget extends StatefulWidget {
  final Widget child;
  final ValueChanged<List<String>> onFilesDropped;

  const MediaDropTarget({
    super.key,
    required this.child,
    required this.onFilesDropped,
  });

  @override
  State<MediaDropTarget> createState() => _MediaDropTargetState();
}

class _MediaDropTargetState extends State<MediaDropTarget> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        setState(() => _isDragging = false);
        final paths = details.files.map((f) => f.path).toList();
        if (paths.isNotEmpty) {
          widget.onFilesDropped(paths);
        }
      },
      child: Stack(
        children: [
          widget.child,
          if (_isDragging)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.clipBlue.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.clipBlue, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.file_download_outlined,
                          size: 40, color: AppColors.clipBlue),
                      SizedBox(height: 8),
                      Text(
                        'Drop media files here',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
