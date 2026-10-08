import 'package:flutter/material.dart';
import '../../domain/agent_models.dart';
import '../../domain/message_sender.dart';
import '../../platform/aurai_platform.dart';
import 'ai_contact_page.dart';
import 'chat_controller.dart';
import 'interactive_message_view.dart';
import 'interactive_statistics_sheet.dart';
import 'personal_info_page.dart';
import 'profile_navigation.dart';

/// References use the same complete forms as the card's details action.
class InteractiveReferenceSheet extends StatelessWidget {
  const InteractiveReferenceSheet({
    super.key,
    required this.controller,
    required this.message,
  });
  final ChatController controller;
  final AgentMessage message;

  @override
  Widget build(BuildContext context) {
    final card = message.interactive!;
    final view = card.interactionView(MessageSender.localUser.id);
    if (card.isVote &&
        (view['submitted'] == true ||
            view['closed'] == true ||
            view['phase'] != 'collecting')) {
      return InteractiveStatisticsSheet(
        database: controller.groupStore.database,
        controller: controller,
        messageId: message.id,
      );
    }
    final conversation = controller.activeConversation;
    final members = {
      for (final sender in conversation.creationMembers) sender.id: sender,
      for (final item in [
        ...conversation.messages,
        ...?conversation.searchMessages,
      ])
        if (item.sender != null) item.sender!.id: item.sender!,
      ...conversation.noticeMembers,
    };
    return InteractiveMessageView(
      messageId: message.id,
      card: card,
      fullSheet: true,
      members: members,
      showQuestionRecipient: message.isGroupMessage,
      onOpenMember: (id) => openProfileRoute(
        context,
        MaterialPageRoute(
          builder: (_) => id == MessageSender.localUser.id
              ? PersonalInfoPage(memory: controller.memory)
              : AiContactPage(
                  controller: controller,
                  senderId: id,
                  groupId: message.isGroupMessage ? conversation.id : null,
                ),
        ),
      ),
      onClick: (button, revision, participantRevision, {value}) =>
          controller.clickInteractiveMessage(
            message.id,
            button,
            revision,
            participantRevision,
            value: value,
          ),
      onRetry: (event) =>
          controller.retryInteractiveCallback(message.id, event),
      onCancelVote: (revision, participantRevision) => controller
          .cancelInteractiveVote(message.id, revision, participantRevision),
      onOpenLink: (url) => AuraiPlatform.instance.startIntent({
        'action': 'android.intent.action.VIEW',
        'data': url,
      }),
    );
  }
}
