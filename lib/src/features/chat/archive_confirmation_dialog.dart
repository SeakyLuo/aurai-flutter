import 'package:flutter/material.dart';

import 'app_confirmation_dialog.dart';

class ArchiveConfirmationDialog extends StatelessWidget {
  const ArchiveConfirmationDialog({
    super.key,
    required this.isCurrent,
    this.typeLabel = '任务',
  });
  final bool isCurrent;
  final String typeLabel;

  @override
  Widget build(BuildContext context) => AppConfirmationDialog(
    title: '归档$typeLabel？',
    description:
        '${isCurrent ? '归档后将退出当前$typeLabel。' : ''}消息和草稿会保留，可在“我”的“已归档”中查看或取消归档。',
    confirmLabel: '归档',
  );
}
