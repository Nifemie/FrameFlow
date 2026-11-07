import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_parser.dart';
import '../../providers/project_provider.dart';
import '../../providers/selection_provider.dart';
import '../../services/playback_controller.dart';
import '../../services/project_storage_service.dart';
import '../media/media_panel.dart';
import '../preview/preview_panel.dart';
import '../properties/properties_panel.dart';
import '../timeline/timeline_container.dart';
import 'widgets/bottom_status_bar.dart';
import 'widgets/top_nav_bar.dart';

class MainLayoutScreen extends ConsumerWidget {
  const MainLayoutScreen({super.key});

  void _stampCut(BuildContext context, WidgetRef ref) {
    final playheadMs = ref.read(playheadPositionProvider);
    final fileName = ref.read(projectProvider.notifier).stampCurrentCutPoint(playheadMs);

    if (fileName != null) {
      final timeFormatted = TimeParser.formatDetailed(playheadMs);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1500),
          backgroundColor: AppColors.surfaceLight,
          content: Text(
            '✂️ Cut "$fileName" stamped at $timeFormatted',
            style: const TextStyle(fontSize: 12, color: AppColors.accentOrange, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
  }

  Future<void> _quickSave(BuildContext context, WidgetRef ref) async {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.read(playbackControllerProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () {
          playback.togglePlayPause();
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          playback.stepPrevious();
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          playback.stepNext();
        },
        const SingleActivator(LogicalKeyboardKey.keyM): () {
          _stampCut(context, ref);
        },
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          _quickSave(context, ref);
        },
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
          ref.read(projectProvider.notifier).newProject();
        },
      },
      child: const Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            children: [
              TopNavBar(),
              Expanded(
                child: Row(
                  children: [
                    MediaPanel(),
                    Expanded(child: PreviewPanel()),
                    PropertiesPanel(),
                  ],
                ),
              ),
              TimelineContainer(),
              BottomStatusBar(),
            ],
          ),
        ),
      ),
    );
  }
}
