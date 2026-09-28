part of 'chat_controller.dart';

extension ConversationBranching on ChatController {
  Future<void> createConversationBranch(AgentMessage throughMessage) async {
    final source = activeConversation;
    if (source.kind != ConversationKind.direct) {
      throw StateError('只有私聊可以创建分支');
    }
    if (source.isTemporary) throw StateError('请先保存临时会话，再创建分支');
    if (isBusy || addingImages) throw StateError('请等待当前操作完成，再创建分支');

    final transport = ResponsesTransport(modelSettings.activeConfig);
    _conversationBranchTransport = transport;
    creatingConversationBranch = true;
    final request = AgentMessage(
      id: newMessageId(),
      role: AgentMessageRole.user,
      senderId: MessageSender.localUser.id,
      text: '请把截至这条消息为止的对话压缩总结，并在新聊天中继续。',
      quote:
          MessageQuote(
              messageId: throughMessage.id,
              senderId: throughMessage.senderId,
              text: [
                if (throughMessage.images.isNotEmpty) '[图片]',
                if (throughMessage.interactive != null)
                  '[交互消息] ${throughMessage.interactive!.title}',
                if (throughMessage.htmlGame != null) '[小程序]',
                for (final file in throughMessage.files) '[文件] ${file.name}',
                if (throughMessage.text.isNotEmpty)
                  String.fromCharCodes(throughMessage.text.runes.take(1000)),
              ].join(' '),
            )
            ..senderName =
                throughMessage.sender?.name ?? MessageSender.localUser.name,
      createdAt: DateTime.now(),
    );
    source.messages.add(request);
    source.messageCount++;
    _conversationChanged();
    try {
      try {
        await _store.writer.save(source, makeActive: false);
      } on Object {
        source.messages.removeWhere((message) => message.id == request.id);
        source.messageCount--;
        rethrow;
      }
      final previousSummary = await _usableBranchSummary(
        source,
        throughMessage,
      );
      final history = await _store.reader.messages(
        source.id,
        throughMessageId: throughMessage.id,
        afterCheckpoint: previousSummary?.throughMessageId,
        forModel: true,
      );
      if (!history.any((message) => message.id == throughMessage.id)) {
        throw StateError('这条消息已不存在，无法创建分支');
      }

      final summary = await transport.summarizeMessages(
        history,
        previousSummary: previousSummary?.text,
      );
      final now = DateTime.now();
      final summaryMessage = AgentMessage(
        id: newMessageId(),
        role: AgentMessageRole.assistant,
        senderId: source.defaultSenderId,
        sender: _activeAi!.sender,
        text: summary,
        createdAt: now,
      );
      final branch = Conversation(id: newMessageId(), createdAt: now)
        ..defaultSenderId = source.defaultSenderId
        ..projectId = source.projectId
        ..storedTitle = '${source.title} · 分支'
        ..messages.add(summaryMessage)
        ..messageCount = 1;
      await _store.writer.save(branch, makeActive: false);
      await _interactiveMessage(
        'sendInteractiveMessage',
        {
          'showStatistics': false,
          'title': '已创建新聊天',
          'body': branch.title,
          'buttons': [
            {
              'id': 'open-conversation',
              'label': '进入新聊天',
              'action': 'openConversation',
              'repeatable': true,
              'icon': 'open',
              'showArrow': true,
              'conversationId': branch.id,
            },
          ],
        },
        source,
        source.defaultSenderId,
      );
    } finally {
      _conversationBranchTransport = null;
      creatingConversationBranch = false;
      _conversationChanged();
    }
  }

  Future<void> cancelConversationBranch() =>
      _conversationBranchTransport!.cancel();

  Future<ContextSummary?> _usableBranchSummary(
    Conversation source,
    AgentMessage throughMessage,
  ) async {
    final summary = source.contextSummary;
    if (summary == null) return null;
    final rows = await _store.database.query(
      'messages',
      columns: ['id', 'created_at'],
      where: 'conversation_id = ? AND id IN (?, ?)',
      whereArgs: [source.id, summary.throughMessageId, throughMessage.id],
    );
    if (rows.length != 2) return null;
    final createdAt = {
      for (final row in rows) row['id'] as String: row['created_at'] as int,
    };
    return createdAt[summary.throughMessageId]! <= createdAt[throughMessage.id]!
        ? summary
        : null;
  }
}
