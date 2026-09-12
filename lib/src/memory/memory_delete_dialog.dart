import 'package:flutter/material.dart';

import '../features/chat/delete_confirmation_dialog.dart';

class MemoryDeleteDialog extends StatelessWidget {
  const MemoryDeleteDialog({super.key});

  @override
  Widget build(BuildContext context) => const DeleteConfirmationDialog(
    title: '删除这条记忆？',
    description: '删除后，Aurai 将不再参考这条记忆。',
  );
}
