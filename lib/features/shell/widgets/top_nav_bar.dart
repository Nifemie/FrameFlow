import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/project.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/project_storage_service.dart';
import '../../export/widgets/export_dialog.dart';
import 'project_rename_dialog.dart';
import 'shortcuts_dialog.dart';
import 'theme_customizer_dialog.dart';

class TopNavBar extends ConsumerWidget {
  const TopNavBar({super.key});

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final project = ref.read(projectProvider);
    final fileName = '${project.name.toLowerCase().replaceAll(' ', '_')}.frameflow';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Project', fileName: fileName, type: FileType.custom, allowedExtensions: ['frameflow'],
    );
    if (savePath != null) {
      await ProjectStorageService.saveProject(project, savePath);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to $savePath')));
    }
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Open Project', type: FileType.custom, allowedExtensions: ['frameflow', 'json'],
    );
    if (result != null && result.files.single.path != null) {
      final loaded = await ProjectStorageService.loadProject(result.files.single.path!);
      ref.read(projectProvider.notifier).loadProject(loaded);
      ref.read(selectedImageIdProvider.notifier).state = null;
      ref.read(playheadPositionProvider.notifier).state = 0;
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loaded: ${loaded.name}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider);
    final notifier = ref.read(projectProvider.notifier);
    final theme = ref.watch(themeProvider);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.topPanelColor,
        border: const Border(bottom: BorderSide(color: AppColors.surfaceBorder, width: 1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 1440;
          final isVeryCompact = constraints.maxWidth < 1220;

          return Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset(
                    'assets/images/app_logo.jpg',
                    width: 22,
                    height: 22,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.movie_creation_outlined,
                      color: AppColors.accentOrange,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!isVeryCompact) ...[
                Text(AppConstants.appName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textColor)),
                const SizedBox(width: 8),
              ],
              const VerticalDivider(width: 1, indent: 12, endIndent: 12, color: AppColors.surfaceBorder),
              const SizedBox(width: 2),

              // File actions
              IconButton(icon: Icon(Icons.note_add_outlined, size: 17, color: theme.iconColor('newProject', theme.textColor)), tooltip: 'New (Ctrl+N)', splashRadius: 16, onPressed: notifier.newProject),
              IconButton(icon: Icon(Icons.folder_open_outlined, size: 17, color: theme.iconColor('openProject', theme.textColor)), tooltip: 'Open (Ctrl+O)', splashRadius: 16, onPressed: () => _open(context, ref)),
              IconButton(icon: Icon(Icons.save_outlined, size: 17, color: theme.iconColor('saveProject', theme.textColor)), tooltip: 'Save (Ctrl+S)', splashRadius: 16, onPressed: () => _save(context, ref)),

              const SizedBox(width: 2),
              IconButton(
                icon: const Icon(Icons.undo, size: 17),
                tooltip: 'Undo (Ctrl+Z)',
                splashRadius: 16,
                onPressed: notifier.canUndo ? notifier.undo : null,
                color: notifier.canUndo ? theme.iconColor('undo', theme.textColor) : AppColors.textMuted.withValues(alpha: 0.4),
              ),
              IconButton(
                icon: const Icon(Icons.redo, size: 17),
                tooltip: 'Redo (Ctrl+Y)',
                splashRadius: 16,
                onPressed: notifier.canRedo ? notifier.redo : null,
                color: notifier.canRedo ? theme.iconColor('redo', theme.textColor) : AppColors.textMuted.withValues(alpha: 0.4),
              ),

              const SizedBox(width: 2),
              const VerticalDivider(width: 1, indent: 12, endIndent: 12, color: AppColors.surfaceBorder),
              const SizedBox(width: 6),

              // Project Title
              InkWell(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => ProjectRenameDialog(currentName: project.name, onSaved: notifier.setProjectName),
                ),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: isCompact ? 90 : 130),
                        child: Text(
                          project.name,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 11, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),
              // Timing Mode Badge (Auto vs Manual)
              InkWell(
                onTap: notifier.toggleTimingMode,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.buttonColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.buttonColor,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        project.timingMode == TimingMode.automatic ? Icons.bolt : Icons.tune,
                        size: 12,
                        color: theme.iconColor('timingMode', theme.buttonColor),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        project.timingMode.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.buttonColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (!isCompact) ...[
                const SizedBox(width: 10),
                const VerticalDivider(width: 1, indent: 12, endIndent: 12, color: AppColors.surfaceBorder),
                const SizedBox(width: 6),

                // Workspace Focus Modes
                _buildFocusButton(ref, WorkspaceFocusMode.normal, Icons.grid_view_rounded, 'Normal Workspace'),
                const SizedBox(width: 2),
                _buildFocusButton(ref, WorkspaceFocusMode.timeline, Icons.view_timeline_rounded, 'Timeline Focus'),
                const SizedBox(width: 2),
                _buildFocusButton(ref, WorkspaceFocusMode.preview, Icons.smart_display_rounded, 'Preview Focus'),
                const SizedBox(width: 2),
                _buildFocusButton(ref, WorkspaceFocusMode.media, Icons.perm_media_rounded, 'Media Focus'),
              ],

              const Spacer(),

              // Theme & Color Customizer button
              IconButton(
                icon: Icon(Icons.palette_outlined, size: 18, color: theme.iconColor('themeCustomize', theme.buttonColor)),
                tooltip: 'Customize Theme & Colors',
                splashRadius: 16,
                onPressed: () => showDialog(context: context, builder: (_) => const ThemeCustomizerDialog()),
              ),
              // Shortcuts info button
              IconButton(
                icon: Icon(Icons.keyboard_outlined, size: 18, color: theme.iconColor('shortcuts', AppColors.textSecondary)),
                tooltip: 'Keyboard Shortcuts',
                splashRadius: 16,
                onPressed: () => showDialog(context: context, builder: (_) => const ShortcutsDialog()),
              ),
              const SizedBox(width: 6),

              // Export Video Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.exportColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: isVeryCompact ? 7 : 10, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                onPressed: () => showDialog(context: context, builder: (_) => const ExportDialog()),
                icon: Icon(Icons.file_upload_outlined, size: 15, color: theme.iconColor('exportVideo', Colors.white)),
                label: Text(
                  isVeryCompact ? 'Export' : 'Export Video',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(width: 6),
              const VerticalDivider(width: 1, indent: 12, endIndent: 12, color: AppColors.surfaceBorder),
              const SizedBox(width: 6),

              // User Account Profile Pill
              _buildUserAccountPill(context, ref, isVeryCompact),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserAccountPill(BuildContext context, WidgetRef ref, [bool isCompact = false]) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final profile = authState.profile;
    final name = (profile?.displayName.isNotEmpty == true)
        ? profile!.displayName
        : (user?.email?.split('@').first ?? 'User');

    return PopupMenuButton<String>(
      tooltip: 'Account Settings',
      padding: EdgeInsets.zero,
      color: AppColors.surface,
      offset: const Offset(0, 38),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.surfaceBorder),
      ),
      onSelected: (val) {
        if (val == 'sign_out') {
          ref.read(authProvider.notifier).signOut();
        } else if (val == 'refresh') {
          ref.read(authProvider.notifier).refreshProfile();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                user?.email ?? '',
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4), width: 0.8),
                ),
                child: const Text(
                  'Plan: Free Early Access (Active)',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'refresh',
          child: Row(
            children: [
              Icon(Icons.sync, size: 14, color: Colors.white70),
              SizedBox(width: 8),
              Text('Sync / Refresh License', style: TextStyle(fontSize: 11, color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'sign_out',
          child: Row(
            children: [
              Icon(Icons.logout, size: 14, color: AppColors.errorRed),
              SizedBox(width: 8),
              Text('Sign Out', style: TextStyle(fontSize: 11, color: AppColors.errorRed)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.surfaceBorder, width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 10,
              backgroundColor: AppColors.accentOrange.withValues(alpha: 0.25),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.accentOrange),
              ),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isCompact ? 60 : 90),
              child: Text(
                name,
                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusButton(WidgetRef ref, WorkspaceFocusMode mode, IconData icon, String tooltip) {
    final activeMode = ref.watch(workspaceFocusModeProvider);
    final btnColor = ref.watch(themeProvider.select((t) => t.buttonColor));
    final isActive = activeMode == mode;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          ref.read(workspaceFocusModeProvider.notifier).state =
              isActive && mode != WorkspaceFocusMode.normal ? WorkspaceFocusMode.normal : mode;
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? btnColor.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isActive ? btnColor : Colors.transparent,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: isActive ? btnColor : ref.watch(themeProvider.select((t) => t.iconColor('workspaceFocus', AppColors.textSecondary))),
          ),
        ),
      ),
    );
  }
}
