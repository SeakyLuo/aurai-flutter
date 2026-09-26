import 'package:flutter/material.dart';
import '../../domain/agent_models.dart';
import '../../domain/message_sender.dart';
import '../../storage/recalled_message_drafts.dart';
import 'group_mention_text.dart';

class RecalledMessageNotice extends StatelessWidget {
  const RecalledMessageNotice({
    super.key,
    required this.message,
    this.onEdit,
    this.onOpenSource,
    this.onOpenMember,
    this.memberNames = const {},
    required this.style,
  });
  final AgentMessage message;
  final ValueChanged<AgentMessage>? onEdit;
  final TextStyle style;
  final ValueChanged<String>? onOpenSource;
  final ValueChanged<String>? onOpenMember;
  final Map<String, String> memberNames;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: _notice(context),
  );

  Widget _notice(BuildContext context) {
    final text = message.isSystem && memberNames.isNotEmpty
        ? GroupMentionText(
            text: message.text,
            style: style,
            members: memberNames,
            bareNames: true,
            textAlign: TextAlign.center,
            onOpen: onOpenMember,
          )
        : Text(message.text, textAlign: TextAlign.center, style: style);
    if (message.quote != null && onOpenSource != null) {
      return Semantics(
        button: true,
        label: '定位交互消息',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onOpenSource!(message.quote!.messageId),
          child: text,
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
              child: Text(
                '重新编辑',
                style: style.copyWith(
                  color: Theme.of(
                    context,
                  ).textButtonTheme.style!.foregroundColor!.resolve(const {}),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
