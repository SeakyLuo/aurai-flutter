import 'package:flutter/material.dart';

import 'app_confirmation_dialog.dart';

class ArchiveConfirmationDialog extends StatelessWidget {
  const ArchiveConfirmationDialog({super.key, required this.isCurrent});
  final bool isCurrent;

  @override
  Widget build(BuildContext context) => AppConfirmationDialog(
    title: '归档会话？',
    description: '${isCurrent ? '归档后将退出当前会话。' : ''}消息和草稿会保留，可在“我”的“已归档会话”中查看或取消归档。',
    confirmLabel: '归档',
  );
}
