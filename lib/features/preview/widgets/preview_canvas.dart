import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/asset_transform.dart';
import '../../../models/image_item.dart';
import '../../../models/project.dart';
import '../../../models/text_overlay_item.dart';
import '../../../providers/project_provider.dart';
import '../../../providers/selection_provider.dart';
import '../../../services/animation_transform_evaluator.dart';
import '../../../services/image_dimension_service.dart';
import '../../../services/video_metadata_service.dart';
import '../../../services/video_playback_engine.dart';
import 'animated_text_overlay.dart';
import 'transform_gizmo.dart';

class PreviewCanvas extends ConsumerStatefulWidget {
  final List<({ImageItem image, bool isVisible})> activeLayers;
  final VideoAspectRatio aspectRatio;
  final bool hasMedia;
  final List<TextOverlayItem> textOverlays;
  final int playheadMs;
  final bool isTextTrackVisible;

  const PreviewCanvas({
    super.key,
    required this.activeLayers,
    required this.aspectRatio,
    this.hasMedia = false,
    this.textOverlays = const [],
    this.playheadMs = 0,
    this.isTextTrackVisible = true,
  });

  @override
  ConsumerState<PreviewCanvas> createState() => _PreviewCanvasState();
}

class _PreviewCanvasState extends ConsumerState<PreviewCanvas> {
  AssetTransform? _ephemeralTransform;
  String? _ephemeralId;

  @override
  void initState() {
    super.initState();
    _prefetch();
  }

  @override
  void didUpdateWidget(covariant PreviewCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldPaths = oldWidget.activeLayers.map((l) => l.image.filePath).join(',');
    final newPaths = widget.activeLayers.map((l) => l.image.filePath).join(',');
    if (oldPaths != newPaths) {
      _prefetch();
    }
  }

  void _prefetch() {
    for (final l in widget.activeLayers) {
      if (l.image.isVideo) {
        if (VideoMetadataService.getCachedThumbnail(l.image.filePath) == null) {
          VideoMetadataService.getThumbnailPath(l.image.filePath).then((t) {
            if (t != null && mounted) setState(() {});
          });
        }
        final offset = (widget.playheadMs - l.image.startMs).clamp(0, l.image.durationMs);
        VideoPlaybackEngine.prepareVideo(l.image, offset);
      } else if (!l.image.isColorBackground && ImageDimensionService.getSize(l.image.filePath) == null) {
        ImageDimensionService.resolve(l.image.filePath).then((size) {
          if (size != null && mounted) setState(() {});
        });
      }
    }
  }

  Widget _buildImageContent(ImageItem item) {
    if (item.isColorBackground) {
      return Container(width: double.infinity, height: double.infinity, color: item.backgroundColor ?? Colors.black);
    }
    if (item.isVideo) {
      return _buildVideoContent(item);
    }

    final imageFile = File(item.filePath);
    switch (item.fitMode) {
      case ImageFitMode.fit:
        return Center(child: Image.file(imageFile, cacheWidth: 1920, fit: BoxFit.contain, errorBuilder: (_, err, _) => _buildError(err)));
      case ImageFitMode.fill:
        return Image.file(imageFile, cacheWidth: 1920, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, err, _) => _buildError(err));
      case ImageFitMode.blurredBackground:
        return Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: Image.file(imageFile, cacheWidth: 200, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())),
            Container(color: Colors.black.withValues(alpha: 0.3)),
            Center(child: Image.file(imageFile, cacheWidth: 1920, fit: BoxFit.contain, errorBuilder: (_, err, _) => _buildError(err))),
          ],
        );
      case ImageFitMode.center:
        return Center(child: Image.file(imageFile, cacheWidth: 1920, fit: BoxFit.none, errorBuilder: (_, err, _) => _buildError(err)));
    }
  }

  Widget _buildVideoContent(ImageItem item) {
    if (VideoPlaybackEngine.isTestEnvironment) {
      return Container(color: Colors.black);
    }

    BoxFit boxFit;
    switch (item.fitMode) {
      case ImageFitMode.fit:
        boxFit = BoxFit.contain;
        break;
      case ImageFitMode.fill:
        boxFit = BoxFit.cover;
        break;
      case ImageFitMode.blurredBackground:
        boxFit = BoxFit.contain;
        break;
      case ImageFitMode.center:
        boxFit = BoxFit.none;
        break;
    }

    final thumbPath = VideoMetadataService.getCachedThumbnail(item.filePath);
    final fallbackWidget = (thumbPath != null && File(thumbPath).existsSync())
        ? Image.file(File(thumbPath), cacheWidth: 1920, fit: boxFit)
        : Container(
            color: Colors.black,
            child: const Center(
              child: Icon(Icons.movie_creation_rounded, size: 40, color: AppColors.accentOrange),
            ),
          );

    if (VideoPlaybackEngine.isTestEnvironment) {
      return fallbackWidget;
    }

    return ValueListenableBuilder<int?>(
      valueListenable: VideoPlaybackEngine.controller.id,
      builder: (context, textureId, _) {
        if (textureId == null || VideoPlaybackEngine.currentFilePath != item.filePath) {
          return fallbackWidget;
        }
        return RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              fallbackWidget,
              Video(
                key: ValueKey('active_video_${item.id}'),
                controller: VideoPlaybackEngine.controller,
                fit: boxFit,
                fill: Colors.transparent,
                controls: NoVideoControls,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildError(dynamic err) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image, size: 48, color: AppColors.errorRed),
          const SizedBox(height: 8),
          const Text('Image file not found', style: TextStyle(color: AppColors.textMuted)),
          if (err != null)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('$err', style: const TextStyle(fontSize: 10, color: Colors.amber), maxLines: 2, textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _buildTransformedLayer(ImageItem item, BoxConstraints constraints, String? selectedId) {
    final isSelected = selectedId == item.id;
    final baseT = (isSelected && _ephemeralId == item.id && _ephemeralTransform != null) ? _ephemeralTransform! : item.transform;

    final evalT = item.animations.isEmpty
        ? baseT
        : AnimationTransformEvaluator.evaluate(
            baseTransform: baseT,
            animations: item.animations,
            clipElapsedMs: widget.playheadMs - item.startMs,
            clipDurationMs: item.durationMs,
          );

    final offsetX = evalT.positionX * constraints.maxWidth * 0.5;
    final offsetY = evalT.positionY * constraints.maxHeight * 0.5;

    return GestureDetector(
      onTap: () => ref.read(selectedImageIdProvider.notifier).state = item.id,
      child: Transform.translate(
        offset: Offset(offsetX, offsetY),
        child: Transform.rotate(
          angle: evalT.rotation,
          child: Transform.scale(
            scale: evalT.scaleX,
            child: Opacity(opacity: evalT.opacity.clamp(0.0, 1.0), child: _buildImageContent(item)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedImageId = ref.watch(selectedImageIdProvider);
    final visibleLayers = widget.activeLayers.where((l) => l.isVisible).toList();
    final selectedLayer = visibleLayers.where((l) => l.image.id == selectedImageId).firstOrNull;

    return Center(
      child: AspectRatio(
        aspectRatio: widget.aspectRatio.ratioValue,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
            return Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.black, borderRadius: BorderRadius.circular(4), border: Border.all(color: AppColors.surfaceBorder, width: 1),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ...visibleLayers.map((l) => _buildTransformedLayer(l.image, constraints, selectedImageId)),
                  if (widget.activeLayers.isEmpty && !widget.hasMedia)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.movie_creation_outlined, size: 40, color: AppColors.textMuted),
                              SizedBox(height: 6),
                              Text('Preview Stage', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
                              SizedBox(height: 2),
                              Text('Add images or background to begin', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (widget.isTextTrackVisible)
                    ...widget.textOverlays.map((item) => AnimatedTextOverlay(item: item, playheadMs: widget.playheadMs)),
                  if (selectedLayer != null && !selectedLayer.image.isColorBackground)
                    TransformGizmo(
                      transform: (_ephemeralId == selectedLayer.image.id && _ephemeralTransform != null) ? _ephemeralTransform! : selectedLayer.image.transform,
                      canvasSize: canvasSize,
                      naturalImageSize: ImageDimensionService.getSize(selectedLayer.image.filePath),
                      fitMode: selectedLayer.image.fitMode,
                      onTransformChanged: (newT) => setState(() { _ephemeralId = selectedLayer.image.id; _ephemeralTransform = newT; }),
                      onTransformCommitted: (finalT) {
                        setState(() { _ephemeralId = null; _ephemeralTransform = null; });
                        ref.read(projectProvider.notifier).updateImageTransform(selectedLayer.image.id, finalT);
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
