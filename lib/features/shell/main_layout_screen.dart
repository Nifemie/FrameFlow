import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/time_parser.dart';
import '../../providers/export_range_provider.dart';
import '../../providers/project_provider.dart';
import '../../providers/selection_provider.dart';
import '../../providers/shortcut_provider.dart';
import '../../services/playback_controller.dart';
import '../../services/project_storage_service.dart';
import '../export/widgets/export_dialog.dart';
import '../media/media_panel.dart';
import '../preview/preview_panel.dart';
import '../properties/properties_panel.dart';
import '../timeline/services/timeline_zoom_controller.dart';
import '../timeline/timeline_container.dart';
import '../timeline/widgets/animation_randomisation_dialog.dart';
import 'widgets/bottom_status_bar.dart';
import 'widgets/top_nav_bar.dart';

class MainLayoutScreen extends ConsumerStatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  ConsumerState<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends ConsumerState<MainLayoutScreen> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    super.dispose();
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted) return false;
    // Do not intercept if a modal dialog is open or user is typing in a text field
    if (ModalRoute.of(context)?.isCurrent != true) return false;

    final focus = FocusManager.instance.primaryFocus;
    final isTyping = focus != null &&
        (focus.context?.widget is EditableText ||
            focus.context?.findAncestorWidgetOfExactType<EditableText>() != null);
    if (isTyping) {
      if (HardwareKeyboard.instance.isControlPressed && event.logicalKey == LogicalKeyboardKey.keyS) {
        _quickSave(context, ref);
        return true;
      }
      return false;
    }

    final playback = ref.read(playbackControllerProvider);
    final notifier = ref.read(projectProvider.notifier);
    final shortcuts = ref.read(shortcutProvider);
    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    if (isCtrl) {
      if (event.logicalKey == LogicalKeyboardKey.keyZ) {
        if (isShift) {
          if (notifier.redo() && mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: Duration(milliseconds: 800), content: Text('↪️ Redo')));
          }
        } else {
          if (notifier.undo() && mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: Duration(milliseconds: 800), content: Text('↩️ Undo')));
          }
        }
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyY) {
        if (notifier.redo() && mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(duration: Duration(milliseconds: 800), content: Text('↪️ Redo')));
        }
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyS) { _quickSave(context, ref); return true; }
      if (event.logicalKey == LogicalKeyboardKey.keyN) { notifier.newProject(); return true; }
      if (event.logicalKey == LogicalKeyboardKey.keyE) { showDialog(context: context, builder: (_) => const ExportDialog()); return true; }
      if (event.logicalKey == LogicalKeyboardKey.keyD) {
        final sel = ref.read(selectedImageIdProvider);
        if (sel != null) notifier.duplicateImage(sel);
        return true;
      }
      if (isShift && event.logicalKey == LogicalKeyboardKey.keyA) {
        showDialog(context: context, builder: (_) => const AnimationRandomisationDialog());
        return true;
      }
      return false;
    }

    if (event.logicalKey == shortcuts.playPauseKey) { playback.togglePlayPause(); return true; }
    if (event.logicalKey == shortcuts.splitKey) { _splitClip(context, ref); return true; }
    if (event.logicalKey == shortcuts.stampKey) { _stampCut(context, ref); return true; }
    if (event.logicalKey == LogicalKeyboardKey.keyK) {
      final ms = ref.read(playheadPositionProvider);
      final count = ref.read(projectProvider).markers.length + 1;
      notifier.addMarker(ms, label: 'Marker $count');
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyI) {
      final ms = ref.read(playheadPositionProvider);
      final totalMs = ref.read(projectProvider).totalDurationMs;
      ref.read(exportRangeProvider.notifier).setInPoint(ms, totalDurationMs: totalMs);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyO) {
      final ms = ref.read(playheadPositionProvider);
      final totalMs = ref.read(projectProvider).totalDurationMs;
      ref.read(exportRangeProvider.notifier).setOutPoint(ms, totalDurationMs: totalMs);
      return true;
    }
    if (HardwareKeyboard.instance.isAltPressed && event.logicalKey == LogicalKeyboardKey.keyX) {
      ref.read(exportRangeProvider.notifier).clearRange();
      return true;
    }
    if (event.logicalKey == shortcuts.deleteKey || event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace) {
      final audioSel = ref.read(selectedAudioClipIdProvider);
      if (audioSel != null) {
        notifier.deleteAudioClip(audioSel);
        ref.read(selectedAudioClipIdProvider.notifier).state = null;
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            duration: Duration(milliseconds: 1000),
            content: Text('🗑️ Removed audio clip'),
          ));
        }
        return true;
      }

      final textSel = ref.read(selectedTextOverlayIdProvider);
      if (textSel != null) {
        notifier.deleteTextOverlay(textSel);
        ref.read(selectedTextOverlayIdProvider.notifier).state = null;
        return true;
      }

      final multiSel = ref.read(selectedClipIdsProvider);
      final singleSel = ref.read(selectedImageIdProvider);
      final toDelete = multiSel.isNotEmpty ? multiSel : (singleSel != null ? {singleSel} : <String>{});
      if (toDelete.isNotEmpty) {
        notifier.removeClipsPreservingGaps(toDelete);
        ref.read(selectedClipIdsProvider.notifier).state = {};
        ref.read(selectedImageIdProvider.notifier).state = null;
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            duration: const Duration(milliseconds: 1000),
            content: Text('🗑️ Removed ${toDelete.length} clip(s) — blank space preserved'),
          ));
        }
      }
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) { playback.stepPrevious(); return true; }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) { playback.stepNext(); return true; }
    if (event.logicalKey == LogicalKeyboardKey.equal) {
      final z = ref.read(timelineZoomProvider);
      ref.read(timelineZoomProvider.notifier).state = (z + 0.25).clamp(TimelineZoomController.minZoom, TimelineZoomController.maxZoom);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.minus) {
      final z = ref.read(timelineZoomProvider);
      ref.read(timelineZoomProvider.notifier).state = (z - 0.25).clamp(TimelineZoomController.minZoom, TimelineZoomController.maxZoom);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.home) {
      if (isShift) { playback.seek(0); } else {
        final totalMs = ref.read(projectProvider).totalDurationMs;
        final w = MediaQuery.of(context).size.width - 64;
        ref.read(timelineZoomProvider.notifier).state = TimelineZoomController.calculateFitZoom(totalDurationMs: totalMs, viewportWidth: w);
      }
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.end && isShift) {
      playback.seek(ref.read(projectProvider).totalDurationMs);
      return true;
    }
    return false;
  }

  void _stampCut(BuildContext context, WidgetRef ref) {
    final playheadMs = ref.read(playheadPositionProvider);
    final fileName = ref.read(projectProvider.notifier).stampCurrentCutPoint(playheadMs);
    if (fileName != null && context.mounted) {
      final timeStr = TimeParser.formatDetailed(playheadMs);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(milliseconds: 1200),
        backgroundColor: AppColors.surfaceLight,
        content: Text('✂️ Cut "$fileName" at $timeStr', style: const TextStyle(fontSize: 12, color: AppColors.accentOrange, fontWeight: FontWeight.bold)),
      ));
    }
  }

  void _splitClip(BuildContext context, WidgetRef ref) {
    final playhead = ref.read(playheadPositionProvider);
    final selectedAudioId = ref.read(selectedAudioClipIdProvider);
    final ok = ref.read(projectProvider.notifier).smartSplitAtPlayhead(playhead, selectedAudioId: selectedAudioId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        duration: const Duration(milliseconds: 1200),
        content: Text(ok ? '✂️ Clip split at ${TimeParser.formatDetailed(playhead)}' : 'Cannot split: place playhead inside clip (>100ms from edges)'),
      ));
    }
  }

  Future<void> _quickSave(BuildContext context, WidgetRef ref) async {
    final project = ref.read(projectProvider);
    final defaultFileName = '${project.name.toLowerCase().replaceAll(' ', '_')}.frameflow';
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Project', fileName: defaultFileName, type: FileType.custom, allowedExtensions: ['frameflow'],
    );
    if (savePath != null) {
      await ProjectStorageService.saveProject(project, savePath);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to $savePath')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const TopNavBar(),
          Expanded(child: _buildWorkspaceArea(context, ref)),
          const BottomStatusBar(),
        ],
      ),
    );
  }

  Widget _buildWorkspaceArea(BuildContext context, WidgetRef ref) {
    final focusMode = ref.watch(workspaceFocusModeProvider);
    final timelineHeight = ref.watch(timelineHeightProvider);

    switch (focusMode) {
      case WorkspaceFocusMode.timeline:
        return Column(
          children: [
            const SizedBox(
              height: 200,
              child: Row(
                children: [
                  SizedBox(width: 280, child: MediaPanel()),
                  Expanded(child: PreviewPanel()),
                  PropertiesPanel(),
                ],
              ),
            ),
            _buildVerticalSplitter(context, ref),
            const Expanded(child: TimelineContainer()),
          ],
        );

      case WorkspaceFocusMode.preview:
        return const Column(
          children: [
            Expanded(child: PreviewPanel()),
            SizedBox(height: 220, child: TimelineContainer()),
          ],
        );

      case WorkspaceFocusMode.media:
        return Column(
          children: [
            const Expanded(
              child: Row(
                children: [
                  SizedBox(width: 580, child: MediaPanel()),
                  Expanded(child: PreviewPanel()),
                  PropertiesPanel(),
                ],
              ),
            ),
            _buildVerticalSplitter(context, ref),
            SizedBox(
              height: timelineHeight.clamp(200.0, 520.0),
              child: const TimelineContainer(),
            ),
          ],
        );

      case WorkspaceFocusMode.normal:
        return Column(
          children: [
            const Expanded(
              child: Row(
                children: [
                  SizedBox(width: 280, child: MediaPanel()),
                  Expanded(child: PreviewPanel()),
                  PropertiesPanel(),
                ],
              ),
            ),
            _buildVerticalSplitter(context, ref),
            SizedBox(
              height: timelineHeight.clamp(200.0, 520.0),
              child: const TimelineContainer(),
            ),
          ],
        );
    }
  }

  Widget _buildVerticalSplitter(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (details) {
        final currentH = ref.read(timelineHeightProvider);
        final screenH = MediaQuery.of(context).size.height;
        final newH = (currentH - details.delta.dy).clamp(160.0, screenH - 220.0);
        ref.read(timelineHeightProvider.notifier).state = newH;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: Container(
          height: 6,
          color: AppColors.surface,
          alignment: Alignment.center,
          child: Container(
            width: 36,
            height: 2,
            decoration: BoxDecoration(
              color: AppColors.surfaceBorder,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }
}