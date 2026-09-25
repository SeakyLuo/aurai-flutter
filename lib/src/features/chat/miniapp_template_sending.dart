part of 'chat_controller.dart';

extension MiniappTemplateSending on ChatController {
  Future<void> sendMiniappTemplate(
    String? targetId,
    MiniappTemplate template,
    String note,
  ) async {
    await _enqueueForward(() => _sendMiniappTemplate(targetId, template, note));
  }

  Future<String> _sendMiniappTemplate(
    String? targetId,
    MiniappTemplate template,
    String note, {
    Map<String, Object?>? fixedResult,
    String? fixedHtml,
  }) async {
    // The recipient picker selects an existing conversation.
    final target = await _forwardTarget(targetId!);
    if (target.kind == ConversationKind.direct &&
        !(await _directReplyContext(target)).config.isConfigured) {
      throw StateError('请先为这个 AI 配置模型，再发送小程序');
    }
    await _store.writer.flush();
    await _store.writer.save(target, makeActive: false);
    final participants = target.kind == ConversationKind.group
        ? (await groupStore.members(target.id)).map((m) => m.sender.id).toList()
        : [MessageSender.localUser.id, target.defaultSenderId];
    final message = await htmlStore.create(
      onCreated: (txn, message) async {
        await txn.rawUpdate(
          'UPDATE conversations SET message_count = (SELECT COUNT(*) FROM messages WHERE conversation_id = ?), preview = ?, updated_at = MAX(updated_at, ?)${target.kind == ConversationKind.direct ? ', pending_goal = ?' : ''} WHERE id = ?',
          [
            target.id,
            message.text,
            message.createdAt.microsecondsSinceEpoch,
            if (target.kind == ConversationKind.direct) message.text,
            target.id,
          ],
        );
        if (target.kind == ConversationKind.group) {
          final batch = txn.batch();
          for (final id in participants.where(
            (id) => id != MessageSender.localUser.id,
          )) {
            batch.insert('message_recipients', {
              'message_id': message.id,
              'sender_id': id,
            });
          }
          await batch.commit(noResult: true);
        }
      },
      conversationId: target.id,
      creator: MessageSender.localUser,
      role: AgentMessageRole.user,
      standalone: true,
      newSession: true,
      forwardedResult: fixedResult,
      forwardedHtml: fixedHtml,
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
    await _inConversation(target, () async {
      if (target.kind == ConversationKind.direct) {
        target.pendingGoal = message.text;
        _execution.queuedUserMessageId = message.id;
      }
      for (final conversation in _interactiveConversations(target.id, target)) {
        if (!conversation.messages.any((m) => m.id == message.id)) {
          conversation.messages.add(message);
          conversation.messageCount++;
        }
      }
      _store.writer.remember([message]);
      _conversationChanged();
      _updateConversationList(target);
      unawaited(_deliverForwardedMessage(target, message));
    });
    HtmlGameSignals.changes.add(message.id);
    return message.id;
  }
}
