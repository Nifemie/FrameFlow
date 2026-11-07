import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/time_parser.dart';
import '../../../models/image_item.dart';
import '../../../providers/project_provider.dart';

class TimestampEditor extends StatefulWidget {
  final ImageItem item;
  final bool isLastImage;
  final bool hasVoiceOver;

  const TimestampEditor({
    super.key,
    required this.item,
    required this.isLastImage,
    required this.hasVoiceOver,
  });

  @override
  State<TimestampEditor> createState() => _TimestampEditorState();
}

class _TimestampEditorState extends State<TimestampEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.item.userEndTimestampInput ?? TimeParser.formatStandard(widget.item.endMs),
    );
  }

  @override
  void didUpdateWidget(covariant TimestampEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.userEndTimestampInput != widget.item.userEndTimestampInput) {
      _controller.text = widget.item.userEndTimestampInput ??
          TimeParser.formatStandard(widget.item.endMs);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'End Timestamp',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                hintText: 'e.g. 00:05 or 12.5',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: AppColors.surfaceBorder),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check, size: 16, color: AppColors.clipBlue),
                  onPressed: () {
                    ref.read(projectProvider.notifier).updateTimestamp(
                          widget.item.id,
                          _controller.text.trim(),
                        );
                  },
                ),
              ),
              onSubmitted: (val) {
                ref.read(projectProvider.notifier).updateTimestamp(
                      widget.item.id,
                      val.trim(),
                    );
              },
            ),
            if (widget.isLastImage && widget.hasVoiceOver)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '⚡ Auto-extends to voice-over duration',
                  style: TextStyle(fontSize: 10, color: AppColors.clipBlueLight),
                ),
              ),
            if (widget.item.validationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.errorRed),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.item.validationError!,
                        style: const TextStyle(fontSize: 10, color: AppColors.errorRed),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
