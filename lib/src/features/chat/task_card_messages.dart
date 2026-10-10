part of 'chat_controller.dart';

extension TaskCardMessages on ChatController {
  Future<AgentMessage> _sendTaskCardMessage(
    Conversation source,
    Conversation task,
    ExecutionReplyContext reply,
    ToolCall call, {
    required bool startExecution,
  }) async {
    final description = call.arguments['description'] as String? ?? task.title;
    final message = AgentMessage(
      id: newMessageId(),
      role: AgentMessageRole.assistant,
      senderId: reply.senderId,
      sender: reply.sender,
      runId: source.activeRunId,
      text: '[任务] ${task.title}\n$description',
      createdAt: DateTime.now(),
      interactive: InteractiveMessage.card(
        revision: 0,
        title: '[任务] ${task.title}',
        body: description,
        buttons: const [],
        participation: {
          'presentation': 'message',
          '_taskCard': {
            'taskId': task.id,
            'title': task.title,
            'description': description,
            'startExecution': startExecution,
            'status': startExecution ? 'running' : 'completed',
          },
        },
      ),
    );
    await _store.writer.mutate(
      () => _store.database.transaction((txn) async {
        await txn.insert('messages', messageRow(source.id, message));
        await txn.rawUpdate(
          'UPDATE conversations SET message_count = message_count + 1, preview = ?, updated_at = ? WHERE id = ?',
          [message.text, message.createdAt.microsecondsSinceEpoch, source.id],
        );
      }),
    );
    _publishInteractiveChange(source.id, message, source: source);
    return message;
  }

  Future<void> _updateTaskCardMessage(
    Conversation source,
    ToolResult result,
  ) async {
    final id = result.output['taskMessageId'] as String?;
    // A failed preparation has no task destination or card to update.
    if (id == null) return;
    if (result.output['pending'] == true ||
        result.output['executionStarted'] == false)
      return;
    await _store.writer.flush();
    final rows = await _store.database.query(
      'messages',
      columns: ['interactive_json'],
      where: 'id = ? AND conversation_id = ?',
      whereArgs: [id, source.id],
      limit: 1,
    );
    // Recalling/deleting the card while the task runs must not recreate it.
    if (rows.isEmpty || rows.single['interactive_json'] == null) return;
    final old = InteractiveMessage.fromJson(
      jsonDecode(rows.single['interactive_json'] as String)
          as Map<String, dynamic>,
    );
    final card = InteractiveMessage.fromJson({
      ...old.toJson(includeParticipants: true),
      'revision': old.revision + 1,
      'participation': {
        ...old.participation,
        '_taskCard': {
          ...old.participation['_taskCard'] as Map,
          'status': AgentStepStatus.fromResult(result).name,
        },
      },
    });
    await _store.writer.mutate(
      () => _store.database.update(
        'messages',
        {
          'interactive_json': jsonEncode(
            card.toJson(includeParticipants: true),
          ),
        },
        where: 'id = ? AND conversation_id = ?',
        whereArgs: [id, source.id],
      ),
    );
    _replaceInteractiveCard(source.id, id, card, source: source);
  }
}
