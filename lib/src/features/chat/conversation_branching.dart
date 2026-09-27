part of 'chat_controller.dart';

extension ConversationBranching on ChatController {
  Future<void> createConversationBranch(AgentMessage throughMessage) async {
    final source = activeConversation;
    if (source.kind != ConversationKind.direct) {
      throw StateError('只有私聊可以创建分支');
    }
    if (source.isTemporary) throw StateError('请先保存临时会话，再创建分支');
    if (isBusy || addingImages) throw StateError('请等待当前操作完成，再创建分支');

    creatingConversationBranch = true;
    _conversationChanged();
    try {
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

      final transport = ResponsesTransport(modelSettings.activeConfig);
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
        text: '**此前对话总结**\n\n$summary',
        createdAt: now,
      );
      final branch = Conversation(id: newMessageId(), createdAt: now)
        ..defaultSenderId = source.defaultSenderId
        ..projectId = source.projectId
        ..storedTitle = '${source.title} · 分支'
        ..messages.add(summaryMessage)
        ..messageCount = 1;
      await _store.writer.save(branch, makeActive: false);
      await _switchConversation(branch.id);
    } finally {
      creatingConversationBranch = false;
      _conversationChanged();
    }
  }

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
