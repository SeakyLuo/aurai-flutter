import 'package:flutter/material.dart';

import '../features/chat/app_dialog.dart';
import '../features/chat/dialog_action_button.dart';

class TaskUnsavedDialog extends StatelessWidget {
  const TaskUnsavedDialog({
    super.key,
    this.description = '任务还有未保存的修改。',
    this.title = '保存修改？',
    this.saveLabel = '保存',
    this.canSave = true,
  });
  final String description;
  final String title;
  final String saveLabel;
  final bool canSave;

  @override
  Widget build(BuildContext context) => AppPromptDialog(
    title: title,
    description: description,
    actions: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canSave) ...[
          DialogActionButton(
            text: saveLabel,
            onPressed: () => Navigator.pop(context, 'save'),
          ),
          const SizedBox(height: 10),
        ],
        DialogActionButton(
          text: '放弃修改',
          role: DialogActionRole.reject,
          onPressed: () => Navigator.pop(context, 'discard'),
        ),
        const SizedBox(height: 10),
        DialogActionButton(
          text: '继续编辑',
          role: DialogActionRole.secondary,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}
