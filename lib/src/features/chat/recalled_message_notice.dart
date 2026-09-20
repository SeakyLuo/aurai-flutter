import 'package:flutter/material.dart';
import '../../domain/agent_models.dart';
import '../../domain/message_sender.dart';
import '../../storage/recalled_message_drafts.dart';

class RecalledMessageNotice extends StatelessWidget {
  const RecalledMessageNotice({
    super.key,
    required this.message,
    this.onEdit,
    this.onOpenSource,
    required this.style,
  });
  final AgentMessage message;
  final ValueChanged<AgentMessage>? onEdit;
  final TextStyle style;
  final ValueChanged<String>? onOpenSource;

  @override
  Widget build(BuildContext context) {
    final text = Text(message.text, textAlign: TextAlign.center, style: style);
    if (message.quote != null && onOpenSource != null) {
      return Semantics(
        button: true,
        label: '定位交互消息',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onOpenSource!(message.quote!.messageId),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: text,
          ),
        ),
      );
    }
    if (message.senderId != MessageSender.localUser.id || onEdit == null) {
      return text;
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: RecalledMessageDrafts.instance.entries,
      builder: (context, snapshot) {
        if (!(snapshot.data?.containsKey(message.id) ?? false)) return text;
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            text,
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => onEdit!(message),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '重新编辑',
                  style: style.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
