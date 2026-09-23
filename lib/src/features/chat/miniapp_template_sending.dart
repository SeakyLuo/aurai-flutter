part of 'chat_controller.dart';

extension MiniappTemplateSending on ChatController {
  Future<void> sendMiniappTemplate(
    String? targetId,
    MiniappTemplate template,
    String note,
  ) => _enqueueForward(() async {
    // The recipient picker selects an existing conversation.
    final target = await _forwardTarget(targetId!);
    await _store.writer.flush();
    await _store.writer.save(target, makeActive: false);
    final participants = target.kind == ConversationKind.group
        ? (await groupStore.members(target.id)).map((m) => m.sender.id).toList()
        : [MessageSender.localUser.id, target.defaultSenderId];
    final message = await htmlGames.create(
      conversationId: target.id,
      creator: MessageSender.localUser,
      role: AgentMessageRole.user,
      standalone: true,
      newSession: true,
      callbackSenderId: target.defaultSenderId,
      groupMessage: target.kind == ConversationKind.group,
      messageText: [template.title, if (note.isNotEmpty) note].join('\n\n'),
      args: {
        ...template.definition,
        'title': template.title,
        'appId': template.appId,
        'participants': participants,
        'turnSenderId': null,
      },
    );
    _publishInteractiveChange(target.id, message, source: target);
    _updateConversationList(target);
    HtmlGameSignals.changes.add(message.id);
  });
}
