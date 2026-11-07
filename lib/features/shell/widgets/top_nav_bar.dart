import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../services/project_storage_service.dart';
import '../../export/widgets/export_dialog.dart';

class TopNavBar extends ConsumerWidget {
  const TopNavBar({super.key});

  Future<void> _saveProject(BuildContext context, WidgetRef ref) async {
    final project = ref.read(projectProvider);
    final defaultFileName = '${project.name.toLowerCase().replaceAll(' ', '_')}.frameflow';

    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Project',
      fileName: defaultFileName,
      type: FileType.custom,
      allowedExtensions: ['frameflow'],
    );

    if (savePath != null) {
      await ProjectStorageService.saveProject(project, savePath);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Project saved to $savePath')),
        );
      }
    }
  }

  Future<void> _openProject(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Open FrameFlow Project',
      type: FileType.custom,
      allowedExtensions: ['frameflow', 'json'],
    );

    if (result != null && result.files.single.path != null) {
      final loaded = await ProjectStorageService.loadProject(result.files.single.path!);
      ref.read(projectProvider.notifier).loadProject(loaded);
      ref.read(selectedImageIdProvider.notifier).state = null;
      ref.read(playheadPositionProvider.notifier).state = 0;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded project: ${loaded.name}')),
        );
      }
    }
  }

  void _renameProject(BuildContext context, WidgetRef ref) {
    final currentName = ref.read(projectProvider).name;
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rename Project', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Project Name'),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              ref.read(projectProvider.notifier).setProjectName(val.trim());
            }
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(projectProvider.notifier).setProjectName(controller.text.trim());
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectName = ref.watch(projectProvider.select((p) => p.name));

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.surfaceBorder, width: 1)),
      ),
      child: Row(
        children: [
          // Logo & Name
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.asset(
              'assets/images/app_logo.jpg',
              width: 22,
              height: 22,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            AppConstants.appName,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 16),
          const VerticalDivider(width: 1, indent: 12, endIndent: 12, color: AppColors.surfaceBorder),
          const SizedBox(width: 8),

          // Project Management Actions: New, Open, Save
          IconButton(
            icon: const Icon(Icons.note_add_outlined, size: 18),
            tooltip: 'New Project (Ctrl+N)',
            splashRadius: 16,
            onPressed: () => ref.read(projectProvider.notifier).newProject(),
          ),
          IconButton(
            icon: const Icon(Icons.folder_open_outlined, size: 18),
            tooltip: 'Open Project (Ctrl+O)',
            splashRadius: 16,
            onPressed: () => _openProject(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.save_outlined, size: 18),
            tooltip: 'Save Project (Ctrl+S)',
            splashRadius: 16,
            onPressed: () => _saveProject(context, ref),
          ),

          const SizedBox(width: 8),
          const VerticalDivider(width: 1, indent: 12, endIndent: 12, color: AppColors.surfaceBorder),
          const SizedBox(width: 12),

          // Editable Project Title
          InkWell(
            onTap: () => _renameProject(context, ref),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Text(
                    projectName,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 12, color: AppColors.textMuted),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Export Video Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.exportGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () => showDialog(context: context, builder: (_) => const ExportDialog()),
            icon: const Icon(Icons.file_upload_outlined, size: 16),
            label: const Text('Export Video', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
