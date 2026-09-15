import 'package:flutter/material.dart';

import 'conversation.dart';
import 'dialog_action_button.dart';
import 'glass_surface.dart';

class TemporaryConversationDialog extends StatelessWidget {
  const TemporaryConversationDialog({super.key});

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    elevation: 0,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: GlassSurface(
        radius: 28,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '发起临时会话',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const Text(
                '个性化：使用已有记忆和自定义指令。\n非个性化：不使用记忆和自定义指令。',
                style: TextStyle(fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 12),
              Text(
                '两种模式均保留记录，不写入记忆，不参与会话搜索。退出后自动归档，可在已归档会话中查看。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              DialogActionButton(
                text: '个性化',
                role: DialogActionRole.secondary,
                onPressed: () => Navigator.pop(
                  context,
                  ConversationMode.temporaryPersonalized,
                ),
              ),
              const SizedBox(height: 10),
              DialogActionButton(
                text: '非个性化',
                role: DialogActionRole.secondary,
                onPressed: () =>
                    Navigator.pop(context, ConversationMode.temporaryPlain),
              ),
              const SizedBox(height: 10),
              DialogActionButton(
                text: '取消',
                role: DialogActionRole.secondary,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
