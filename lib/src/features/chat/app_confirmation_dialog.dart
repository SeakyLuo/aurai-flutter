import 'package:flutter/material.dart';

import 'app_dialog.dart';
import 'dialog_action_button.dart';

/// Returns true for confirmation, false for cancellation, null for dismissal.
class AppConfirmationDialog extends StatelessWidget {
  const AppConfirmationDialog({
    super.key,
    required this.title,
    this.description,
    required this.confirmLabel,
    this.cancelLabel = '取消',
    this.confirmRole = DialogActionRole.primary,
    this.regular = false,
  });

  final String title;
  final String? description;
  final String confirmLabel;
  final String cancelLabel;
  final DialogActionRole confirmRole;
  final bool regular;

  @override
  Widget build(BuildContext context) => AppPromptDialog(
    title: title,
    description: description,
    regular: regular,
    actions: Row(
      children: [
        Expanded(
          child: DialogActionButton(
            text: cancelLabel,
            onPressed: () => Navigator.pop(context, false),
            role: DialogActionRole.secondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DialogActionButton(
            text: confirmLabel,
            onPressed: () => Navigator.pop(context, true),
            role: confirmRole,
          ),
        ),
      ],
    ),
  );
}
