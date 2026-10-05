import 'package:flutter/material.dart';
import '../../domain/agent_models.dart';
import '../../html_games/miniapp_forward.dart';
import '../../html_games/miniapp_share_card.dart';
import 'group_message_heading.dart';

class MiniappShareMessage extends StatelessWidget {
  const MiniappShareMessage({
    super.key,
    required this.message,
    required this.groupBubble,
    required this.onLongPress,
    required this.wrapContent,
  });
  final AgentMessage message;
  final bool groupBubble;
  final VoidCallback onLongPress;
  final Widget Function(Widget) wrapContent;

  @override
  Widget build(BuildContext context) {
    final own = message.role == AgentMessageRole.user;
    final share = message.miniappShare!;
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: own ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: groupBubble
                ? constraints.maxWidth - GroupMessageHeading.ownContentInset
                : (constraints.maxWidth - 32) * .82,
          ),
          margin: EdgeInsets.fromLTRB(
            groupBubble
                ? own
                      ? message.hasRestrictedAudience
                            ? GroupMessageHeading.restrictedRightInset
                            : GroupMessageHeading.rightInset
                      : 18
                : 16,
            groupBubble ? 0 : 12,
            groupBubble ? 18 : 16,
            groupBubble ? 0 : 24,
          ),
          child: wrapContent(
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: own
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                MiniappShareCard(
                  share: share,
                  onTap: () => openMiniappLink(context, Uri.parse(share.uri)),
                  onLongPress: onLongPress,
                ),
                if (share.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onLongPress: onLongPress,
                      child: Text(
                        share.note,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
