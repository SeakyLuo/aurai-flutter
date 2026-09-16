import 'package:flutter/material.dart';

import '../../domain/agent_models.dart';
import '../../html_games/html_game_store.dart';
import '../../html_games/html_game_view.dart';
import '../../storage/group_message_search.dart';
import 'group_message_heading.dart';
import 'message_item.dart';

class GroupSearchMessageTile extends StatelessWidget {
  const GroupSearchMessageTile({
    super.key,
    required this.result,
    required this.conversationId,
    required this.htmlGames,
    required this.time,
    required this.onLocate,
    required this.onOpenProfile,
  });

  final GroupMessageSearchResult result;
  final String conversationId, time;
  final HtmlGameStore htmlGames;
  final VoidCallback onLocate;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final message = AgentMessage(
      id: result.id,
      role: result.role,
      senderId: result.sender.id,
      sender: result.sender,
      text: result.text,
      createdAt: result.createdAt,
      images: result.images,
      files: result.files,
      interactive: result.interactive,
      htmlGame: result.html,
      isGroupMessage: true,
    );
    final content = MessageItem(
      message: message,
      onEdit: null,
      readOnly: result.html == null,
      onLocate: onLocate,
      groupBubble: true,
      onInteractiveClick: (_, _, _) async {
        onLocate();
        return null;
      },
      htmlGameView: result.html == null
          ? null
          : HtmlGameView(
              card: result.html!,
              messageId: result.id,
              conversationId: conversationId,
              store: htmlGames,
            ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Semantics(
        button: true,
        label: '定位原消息',
        onTap: onLocate,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onLocate,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  time,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (result.role == AgentMessageRole.assistant)
                GroupMessageHeading(
                  sender: result.sender,
                  showName: result.html == null,
                  onOpenProfile: onOpenProfile,
                  child: IgnorePointer(
                    ignoring: result.html == null && result.interactive == null,
                    child: content,
                  ),
                )
              else
                IgnorePointer(
                  ignoring: result.html == null && result.interactive == null,
                  child: content,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
