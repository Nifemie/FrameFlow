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
  late TextEditingController _startCtrl;
  late TextEditingController _endCtrl;

  @override
  void initState() {
    super.initState();
    _startCtrl = TextEditingController(
      text: widget.item.userStartTimestampInput ?? TimeParser.formatStandard(widget.item.startMs),
    );
    _endCtrl = TextEditingController(
      text: widget.item.userEndTimestampInput ?? TimeParser.formatStandard(widget.item.endMs),
    );
  }

  @override
  void didUpdateWidget(covariant TimestampEditor old) {
    super.didUpdateWidget(old);
    if (old.item.id != widget.item.id ||
        old.item.userStartTimestampInput != widget.item.userStartTimestampInput) {
      _startCtrl.text = widget.item.userStartTimestampInput ??
          TimeParser.formatStandard(widget.item.startMs);
    }
    if (old.item.id != widget.item.id ||
        old.item.userEndTimestampInput != widget.item.userEndTimestampInput) {
      _endCtrl.text = widget.item.userEndTimestampInput ??
          TimeParser.formatStandard(widget.item.endMs);
    }
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  Widget _buildField(String label, TextEditingController ctrl, ValueChanged<String> onSubmit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: const TextStyle(fontFamily: 'Consolas', fontSize: 12, color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            hintText: '00:00',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppColors.surfaceBorder)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.check, size: 14, color: AppColors.clipBlue),
              onPressed: () => onSubmit(ctrl.text.trim()),
            ),
          ),
          onSubmitted: (val) => onSubmit(val.trim()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final notifier = ref.read(projectProvider.notifier);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildField('Start Time (Gap)', _startCtrl, (v) => notifier.updateStartTimestamp(widget.item.id, v)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildField('End Time', _endCtrl, (v) => notifier.updateTimestamp(widget.item.id, v)),
                ),
              ],
            ),
            if (widget.isLastImage && widget.hasVoiceOver)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('⚡ Auto-extends to voice-over duration', style: TextStyle(fontSize: 10, color: AppColors.clipBlueLight)),
              ),
            if (widget.item.validationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.errorRed),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(widget.item.validationError!, style: const TextStyle(fontSize: 10, color: AppColors.errorRed)),
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
