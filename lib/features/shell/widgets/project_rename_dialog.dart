import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ProjectRenameDialog extends StatefulWidget {
  final String currentName;
  final ValueChanged<String> onSaved;

  const ProjectRenameDialog({
    super.key,
    required this.currentName,
    required this.onSaved,
  });

  @override
  State<ProjectRenameDialog> createState() => _ProjectRenameDialogState();
}

class _ProjectRenameDialogState extends State<ProjectRenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSaved(text);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Rename Project', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Project Name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.clipBlue),
          onPressed: _submit,
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
