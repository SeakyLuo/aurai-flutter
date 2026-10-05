part of 'chat_controller.dart';

extension MiniappContextCompactionActions on ChatController {
  Future<bool> _compactMiniappContext(MiniappProgramChange change) async {
    final eventId = change.contextCompaction!.eventId;
    if (_miniappCompactions[eventId] case final pending?) {
      await pending;
      return false;
    }
    final pending = _applyMiniappCompaction(change);
    _miniappCompactions[eventId] = pending;
    try {
      return await pending;
    } finally {
      _miniappCompactions.remove(eventId);
    }
  }

  Future<bool> _applyMiniappCompaction(MiniappProgramChange change) async {
    final id = change.conversationId;
    final request = change.contextCompaction!;
    final conversations = <Conversation>{
      for (final item in [
        ..._conversations,
        _viewConversation,
        _executions.sessions[id]?.conversation,
        _executions.sessions[id]?.runningConversation,
      ])
        if (item != null && item.id == id) item,
    };
    final contexts = <SharedResponsesContext>{
      for (final conversation in conversations)
        if (conversation.sharedContext != null) conversation.sharedContext!,
    }.toList();
    Future<bool> compact() async {
      final eventRows = await _store.database.query(
        'html_game_events',
        columns: ['snapshot_json'],
        where: 'id = ? AND message_id = ?',
        whereArgs: [request.eventId, change.messageId],
      );
      final snapshot = MiniappProgram.decode(eventRows.single['snapshot_json']);
      if (!snapshot.containsKey('pendingContextChange')) return false;
      final dispatcher = _executions.sessions[id]?.groupDispatcher;
      dispatcher?.hold();
      for (final conversation in conversations) {
        conversation.isCompacting = true;
      }
      _conversationChanged();
      try {
        // Older runs must not overwrite the explicit checkpoint after it commits.
        _store.writer.invalidateHistory(id);
        final historyVersion = _store.writer.historyVersion(id);
        final stored = await _store.load(id);
        final roster = await MiniappProgramStore.members(_store.database, id);
        final agents = [
          for (final member in roster)
            if (member['kind'] == 'agent') member['id'] as String,
        ];
        final checkpoint = await _store.earliestGroupContextCheckpoint(
          stored,
          agents,
        );
        final history = await _store.reader.messages(
          id,
          forModel: true,
          includeSystem: true,
          throughMessageId: request.throughMessageId,
          afterCheckpoint: checkpoint,
        );
        final summaryConfig = modelSettings.activeConfig;
        if (!summaryConfig.isConfigured) throw StateError('请先配置用于压缩上下文的默认模型');
        final indices = {
          for (final (index, message) in history.indexed) message.id: index,
        };
        List<AgentMessage> after(ContextSummary? previous) {
          final cut = previous == null
              ? -1
              : indices[previous.throughMessageId];
          if (cut == null) {
            throw StateError('上下文检查点已变化，请重新触发压缩');
          }
          return history.skip(cut + 1).toList();
        }

        final publicText = await _summarizeMiniappHistory(
          _groupHistory(
            after(
              stored.contextSummary,
            ).where((message) => !message.hasRestrictedAudience).toList(),
            'system:public-summary',
          ),
          stored.contextSummary?.text ?? '',
          request.instructions,
          summaryConfig,
        );
        final publicSummary = ContextSummary(
          text: publicText,
          throughMessageId: request.throughMessageId,
        );
        final privateSummaries = <String, ContextSummary>{};
        // All histories were loaded once. Bound concurrent model calls to four.
        for (var start = 0; start < agents.length; start += 4) {
          await Future.wait([
            for (final senderId in agents.skip(start).take(4))
              () async {
                final previous = stored.privateContextSummaries[senderId];
                final text = await _summarizeMiniappHistory(
                  _groupHistory(
                    after(previous)
                        .where((message) => message.hasRestrictedAudience)
                        .toList(),
                    senderId,
                  ),
                  previous?.text ?? '',
                  request.instructions,
                  summaryConfig,
                );
                privateSummaries[senderId] = ContextSummary(
                  text: text,
                  throughMessageId: request.throughMessageId,
                );
              }(),
          ]);
        }
        await _store.writer.mutate(() async {
          if (_store.writer.historyVersion(id) != historyVersion) {
            throw StateError('压缩期间历史消息发生变化，请重新触发压缩');
          }
          await _store.database.transaction((txn) async {
            final pending = await txn.query(
              'app_state',
              columns: ['value'],
              where: 'key = ?',
              whereArgs: ['context_compaction:$id'],
            );
            if (pending.isEmpty ||
                (MiniappProgram.decode(
                          pending.single['value'],
                        )['contextCompaction']
                        as Map)['eventId'] !=
                    request.eventId) {
              throw StateError('小程序的上下文压缩请求已取消');
            }
            final batch = txn.batch();
            final summaries = {
              'context_summary:$id': publicSummary,
              for (final entry in privateSummaries.entries)
                'context_summary:$id:${entry.key}': entry.value,
            };
            for (final entry in summaries.entries) {
              batch.insert('app_state', {
                'key': entry.key,
                'value': jsonEncode(entry.value.toJson()),
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            batch.update(
              'html_game_events',
              {
                'snapshot_json': jsonEncode(
                  <String, Object?>{...snapshot, 'contextCompacted': true}
                    ..remove('pendingContextChange'),
                ),
              },
              where: 'id = ?',
              whereArgs: [request.eventId],
            );
            batch.delete(
              'app_state',
              where: 'key = ?',
              whereArgs: ['context_compaction:$id'],
            );
            await batch.commit(noResult: true);
          });
        });
        for (final context in contexts) {
          context.replaceHistory(
            publicSummary: publicSummary,
            privateSummaries: privateSummaries,
            throughCreatedAt: request.throughCreatedAt,
            instructions: request.instructions,
          );
        }
        for (final conversation in conversations) {
          conversation.contextSummary = publicSummary;
          conversation.privateContextSummaries
            ..clear()
            ..addAll(privateSummaries);
        }
        return true;
      } finally {
        for (final conversation in conversations) {
          conversation.isCompacting = false;
        }
        dispatcher?.release();
        _conversationChanged();
      }
    }

    Future<bool> lock(int index) => index == contexts.length
        ? compact()
        : contexts[index].exclusive(() => lock(index + 1));
    return lock(0);
  }

  Future<String> _summarizeMiniappHistory(
    List<AgentMessage> messages,
    String previous,
    String instructions,
    ModelConfig config,
  ) async {
    if (messages.isEmpty && previous.isEmpty) return '';
    final input = await responseMessageInput(
      messages,
      supportsImages: configSupportsImageInput(config),
    );
    final transport = ResponsesTransport(config)..beginTurn();
    final context = ResponsesContext(
      ModelContextLimits.forConfig(config),
      systemPrompt: instructions,
    );
    return context.summarizeHistory(
      [
        if (messages.isEmpty)
          {'role': 'assistant', 'content': 'Earlier memory:\n$previous'},
        for (final items in input) ...items,
      ],
      messages.isEmpty ? '' : previous,
      (content) => transport.summarize(content, instructions: instructions),
    );
  }
}
