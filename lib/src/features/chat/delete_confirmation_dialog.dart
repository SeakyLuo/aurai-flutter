import 'dialog_action_button.dart';
import 'package:flutter/material.dart';

import 'app_confirmation_dialog.dart';

class DeleteConfirmationDialog extends StatelessWidget {
  const DeleteConfirmationDialog({
    super.key,
    required this.title,
    required this.description,
    this.confirmLabel = '删除',
    this.cancelLabel = '取消',
  });
  final String title;
  final String description;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) => AppConfirmationDialog(
    title: title,
    description: description,
    confirmLabel: confirmLabel,
    cancelLabel: cancelLabel,
    confirmRole: DialogActionRole.destructive,
    regular: true,
  );
}
