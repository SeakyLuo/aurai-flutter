import 'package:flutter/material.dart';

import '../../app/glass_notice.dart';
import '../../app/ui_action.dart';
import 'chat_controller.dart';
import 'contact_remark_dialog.dart';

Future<void> editContactRemark(
  BuildContext context,
  ChatController controller,
  String senderId,
) async {
  final value = await showDialog<String>(
    context: context,
    builder: (_) => ContactRemarkDialog(senderId: senderId),
  );
  if (value == null || !context.mounted) return;
  await runUiAction(context, () async {
    await controller.setContactRemark(senderId, value);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showToast(
        SnackBar(content: Text(value.isEmpty ? '已恢复原名' : '备注名已保存')),
        kind: ToastKind.success,
      );
    }
  });
}
