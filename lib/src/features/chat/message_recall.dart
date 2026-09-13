part of 'chat_controller.dart';

extension MessageRecall on ChatController {
  Future<void> recallMessage(AgentMessage message) async {
    final conversation = activeConversation;
    if (conversation.kind != ConversationKind.group ||
        message.senderId != MessageSender.localUser.id ||
        message.isSystem)
      return;
    if (!_recallingMessages.add(message.id)) return;
    final notice = AgentMessage(
      id: message.id,
      role: message.role,
      senderId: message.senderId,
      sender: message.sender,
      text: '你撤回了一条消息',
      createdAt: message.createdAt,
      isSystem: true,
    );
    final dispatcher = _runningConversation?.id == conversation.id
        ? _groupDispatcher
        : null;
    final live =
        dispatcher != null && !dispatcher.closed && !dispatcher.stopped;
    if (live) dispatcher.hold();
    try {
      await _store.writer.mutate(() async {
        await _store.database.transaction((txn) async {
          await txn.update(
            'messages',
            {
              'text': notice.text,
              'kind': 'system',
              'quote_json': null,
              'run_id': null,
              'model_turn_id': null,
            },
            where: 'id = ? AND conversation_id = ?',
            whereArgs: [message.id, conversation.id],
          );
          await txn.delete(
            'attachments',
            where: 'message_id = ?',
            whereArgs: [message.id],
          );
          await txn.rawUpdate(
            r"UPDATE messages SET quote_json = json_set(quote_json, '$.text', ?) "
            r"WHERE conversation_id = ? AND json_extract(quote_json, '$.messageId') = ?",
            ['消息已撤回', conversation.id, message.id],
          );
          await txn.rawUpdate(
            r"UPDATE conversations SET draft_quote_json = json_set(draft_quote_json, '$.text', ?) "
            r"WHERE id = ? AND json_extract(draft_quote_json, '$.messageId') = ?",
            ['消息已撤回', conversation.id, message.id],
          );
          await txn.delete(
            'app_state',
            where: 'key = ?',
            whereArgs: ['context_summary:${conversation.id}'],
          );
        });
        final copies = <Conversation>{
          conversation,
          if (_runningConversation?.id == conversation.id)
            _runningConversation!,
          if (_runningConversation?.id == conversation.id) ..._groupRuns.values,
        };
        for (final copy in copies) {
          _replaceRecalled(copy.messages, message.id, notice);
          if (copy.searchMessages != null) {
            _replaceRecalled(copy.searchMessages!, message.id, notice);
          }
          if (copy.draftQuote?.messageId == message.id) {
            copy.draftQuote = _recalledQuote(copy.draftQuote!);
          }
          copy.contextSummary = null;
        }
        if (live) _replaceRecalled(dispatcher.history, message.id, notice);
        _store.writer.remember([notice]);
      });
      await _store.writer.save(conversation, makeActive: false);
      _conversationChanged();
      if (live) {
        dispatcher.start(
          _groupReplies.keys.where((id) => !dispatcher.paused.contains(id)),
        );
      } else {
        await _receiveGroupSystemNotice(conversation.id, notice);
      }
    } finally {
      _recallingMessages.remove(message.id);
      if (live) dispatcher.release();
    }
  }

  MessageQuote _recalledQuote(MessageQuote quote) => MessageQuote(
    messageId: quote.messageId,
    senderId: quote.senderId,
    text: '消息已撤回',
  )..senderName = quote.senderName;

  void _replaceRecalled(
    List<AgentMessage> messages,
    String id,
    AgentMessage notice,
  ) {
    for (var i = 0; i < messages.length; i++) {
      final m = messages[i];
      if (m.id == id) {
        messages[i] = notice;
      } else if (m.quote?.messageId == id) {
        messages[i] = AgentMessage(
          id: m.id,
          role: m.role,
          senderId: m.senderId,
          sender: m.sender,
          text: m.text,
          createdAt: m.createdAt,
          images: m.images,
          files: m.files,
          taskSummary: m.taskSummary,
          runId: m.runId,
          modelTurnId: m.modelTurnId,
          responseInput: m.responseInput,
          isSystem: m.isSystem,
          isGroupMessage: m.isGroupMessage,
          quote: _recalledQuote(m.quote!),
        );
      }
    }
  }
}
