import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';
import '../../../models/voice_over.dart';
import '../../../providers/project_provider.dart';
import '../../../services/audio_probe_service.dart';

class AudioDropCard extends ConsumerWidget {
  const AudioDropCard({super.key});

  Future<void> _pickAudio(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.supportedAudioExtensions,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final fileName = p.basename(path);

      // Reliably detect audio duration via ffprobe or decoder
      final durationMs = await AudioProbeService.getAudioDurationMs(path);

      ref.read(projectProvider.notifier).setVoiceOver(
            VoiceOver(
              filePath: path,
              fileName: fileName,
              durationMs: durationMs,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceOver = ref.watch(projectProvider.select((p) => p.voiceOver));

    if (voiceOver != null) {
      return Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.waveform.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.audiotrack, color: AppColors.waveform, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voiceOver.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Duration: ${TimeParser.formatStandard(voiceOver.durationMs)}',
                    style: const TextStyle(fontSize: 10, color: AppColors.waveform),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
              splashRadius: 16,
              tooltip: 'Remove audio',
              onPressed: () => ref.read(projectProvider.notifier).removeVoiceOver(),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(8),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.surfaceBorder, style: BorderStyle.solid),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        onPressed: () => _pickAudio(context, ref),
        icon: const Icon(Icons.audio_file_outlined, color: AppColors.waveform, size: 18),
        label: const Text(
          'Import Voice-Over Audio',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
