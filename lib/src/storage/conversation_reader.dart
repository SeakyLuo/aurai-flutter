import '../domain/message_file.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/agent_models.dart';
import '../domain/message_image.dart';
import '../features/chat/conversation.dart';
import 'conversation_rows.dart';
import 'protocol_history.dart';
import '../domain/model_provider.dart';

typedef ConversationSearchResult = ({
  Conversation conversation,
  String snippet,
});

class ConversationReader {
  ConversationReader(this.database, this.imageDirectory);
  final Database database;
  final String imageDirectory;
  static const pageSize = 50;
  static const messagePageSize = 100;

  Future<List<Conversation>> list({
    Conversation? after,
    bool archived = false,
  }) async {
    final rows = await database.query(
      'conversations',
      where:
          'archived = ?${after == null ? '' : ' AND (pinned < ? OR (pinned = ? AND (updated_at < ? OR (updated_at = ? AND id < ?))))'}',
      whereArgs: [
        archived ? 1 : 0,
        if (after != null) ...[
          after.isPinned ? 1 : 0,
          after.isPinned ? 1 : 0,
          after.updatedAt.microsecondsSinceEpoch,
          after.updatedAt.microsecondsSinceEpoch,
          after.id,
        ],
      ],
      orderBy: 'pinned DESC, updated_at DESC, id DESC',
      limit: pageSize,
    );
    final values = rows.map(conversationFromRow).toList();
    if (values.isNotEmpty) {
      final results = await Future.wait([
        database.query(
          'attachments',
          where:
              'message_id IS NULL AND conversation_id IN (${_slots(values.length)})',
          whereArgs: values.map((value) => value.id).toList(),
          orderBy: 'position',
        ),
        _loadSeenRuns(values),
      ]);
      final drafts = results[0] as List<Map<String, Object?>>;
      final byId = {for (final value in values) value.id: value};
      for (final image in drafts) {
        if (image['kind'] == 'file') {
          byId[image['conversation_id']]!.draftFiles.add(
            fileFromRow(image, imageDirectory),
          );
          continue;
        }
        byId[image['conversation_id']]!.draftImages.add(
          imageFromRow(image, imageDirectory),
        );
      }
    }
    return values;
  }

  Future<Conversation> load(
    String id, {
    int messageLimit = messagePageSize,
  }) async {
    final rows = await database.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
    );
    final conversation = conversationFromRow(rows.single);
    final results = await Future.wait([
      messages(id, limit: messageLimit),
      database.query(
        'attachments',
        where: 'conversation_id = ? AND message_id IS NULL',
        whereArgs: [id],
        orderBy: 'position',
      ),
      _loadSeenRuns([conversation]),
    ]);
    conversation.messages.addAll(results[0] as List<AgentMessage>);
    conversation.hasEarlierMessages =
        conversation.messages.length == messageLimit;
    conversation.draftImages.addAll(
      (results[1] as List<Map<String, Object?>>)
          .where((row) => row['kind'] != 'file')
          .map((row) => imageFromRow(row, imageDirectory)),
    );
    conversation.draftFiles.addAll(
      (results[1] as List<Map<String, Object?>>)
          .where((row) => row['kind'] == 'file')
          .map((row) => fileFromRow(row, imageDirectory)),
    );
    if (conversation.activeRunId != null) {
      conversation.steps.addAll(await steps(conversation.activeRunId!));
    }
    if (conversation.runState == ChatRunState.failed &&
        conversation.activeRunId != null) {
      final runs = await database.query(
        'agent_runs',
        where: 'id = ?',
        whereArgs: [conversation.activeRunId],
      );
      final run = runs.single;
      final events = await database.query(
        'run_events',
        where: 'run_id = ?',
        whereArgs: [conversation.activeRunId],
        orderBy: 'id',
      );
      final toolRows = await database.query(
        'tool_calls',
        where: 'run_id = ?',
        whereArgs: [conversation.activeRunId],
      );
      final tools = {for (final row in toolRows) row['id']: row};
      var afterMessageId = run['user_message_id'] as String;
      for (final event in events) {
        if (event['kind'] == 'message') {
          afterMessageId = event['message_id'] as String;
        } else if (event['kind'] == 'tool') {
          final tool = tools[event['tool_call_id']]!;
          conversation.liveToolSteps.add((
            afterMessageId: afterMessageId,
            step: AgentStep(
              toolName: tool['name']! as String,
              title: tool['title']! as String,
              requestJson: tool['arguments_json'] as String?,
              resultJson: tool['result_json'] as String?,
              status: AgentStepStatus.values.byName(tool['status']! as String),
            ),
          ));
        }
      }
      if (run['is_task'] == 1) {
        conversation.hasExecutionProcess = true;
        conversation.executionUserMessageId = run['user_message_id'] as String;
        conversation.executionWatch = Stopwatch();
        conversation.restoredExecutionElapsed = Duration(
          milliseconds: run['elapsed_ms'] as int,
        );
      }
    }
    return conversation;
  }

  Future<void> _loadSeenRuns(List<Conversation> conversations) async {
    final byKey = {
      for (final conversation in conversations)
        'seen_run:${conversation.id}': conversation,
    };
    final rows = await database.query(
      'app_state',
      where: 'key IN (${_slots(byKey.length)})',
      whereArgs: byKey.keys.toList(),
    );
    for (final row in rows) {
      byKey[row['key']]!.seenRunId = row['value']! as String;
    }
  }

  Future<List<AgentMessage>> messages(
    String conversationId, {
    AgentMessage? before,
    int limit = messagePageSize,
    bool forModel = false,
    ModelConfig? modelConfig,
    String? afterCheckpoint,
  }) async {
    final selectionWhere =
        'conversation_id = ?${forModel ? " AND NOT (role = 'assistant' AND text = '')" : " AND kind != 'commentary'"}${afterCheckpoint == null ? '' : ' AND created_at >= (SELECT created_at FROM messages WHERE id = ?)'}${before == null ? '' : ' AND (created_at < ? OR (created_at = ? AND id < ?))'}';
    final selectionArgs = <Object?>[
      conversationId,
      if (afterCheckpoint != null) afterCheckpoint,
      if (before != null) ...[
        before.createdAt.microsecondsSinceEpoch,
        before.createdAt.microsecondsSinceEpoch,
        before.id,
      ],
    ];
    final rows = await database.query(
      'messages',
      where: selectionWhere,
      whereArgs: selectionArgs,
      orderBy: 'created_at DESC, id DESC',
      limit: forModel ? null : limit,
    );
    final selectedMessages =
        'SELECT id FROM messages WHERE $selectionWhere ORDER BY created_at DESC, id DESC LIMIT ?';
    final selectedArgs = [...selectionArgs, limit];
    if (rows.isEmpty) return [];
    final images = await database.query(
      'attachments',
      where: forModel
          ? 'conversation_id = ? AND message_id IS NOT NULL'
          : 'message_id IN ($selectedMessages)',
      whereArgs: forModel ? [conversationId] : selectedArgs,
      orderBy: 'position',
    );
    final imageMap = <String, List<MessageImage>>{};
    final fileMap = <String, List<MessageFile>>{};
    for (final image in images) {
      if (image['kind'] == 'file') {
        fileMap
            .putIfAbsent(image['message_id'] as String, () => [])
            .add(fileFromRow(image, imageDirectory));
        continue;
      }
      imageMap
          .putIfAbsent(image['message_id']! as String, () => [])
          .add(imageFromRow(image, imageDirectory));
    }
    final summaries = forModel
        ? <String, AgentTaskSummary>{}
        : await _summaries(selectedMessages, selectedArgs);
    final protocol = modelConfig == null
        ? <String, List<Map<String, Object?>>>{}
        : await loadProtocolHistory(
            database,
            conversationId,
            rows,
            modelConfig,
          );
    return rows.reversed
        .map(
          (row) => AgentMessage(
            id: row['id']! as String,
            role: AgentMessageRole.values.byName(row['role']! as String),
            text: row['text']! as String,
            createdAt: DateTime.fromMicrosecondsSinceEpoch(
              row['created_at']! as int,
            ),
            images: imageMap[row['id']] ?? const [],
            files: fileMap[row['id']] ?? const [],
            runId: row['run_id'] as String?,
            modelTurnId: row['model_turn_id'] as String?,
            taskSummary: summaries[row['id']],
            responseInput: protocol[row['id']],
          ),
        )
        .toList();
  }

  Future<Map<String, AgentTaskSummary>> _summaries(
    String selectedMessages,
    List<Object?> selectedArgs,
  ) async {
    final runWhere =
        'final_message_id IN ($selectedMessages) AND elapsed_ms IS NOT NULL AND is_task = 1';
    final runs = await database.query(
      'agent_runs',
      where: runWhere,
      whereArgs: selectedArgs,
    );
    if (runs.isEmpty) return {};
    final where = 'run_id IN (SELECT id FROM agent_runs WHERE $runWhere)';
    final results = await Future.wait([
      database.query(
        'run_events',
        where: where,
        whereArgs: selectedArgs,
        orderBy: 'id',
      ),
      database.query('messages', where: where, whereArgs: selectedArgs),
      database.query('tool_calls', where: where, whereArgs: selectedArgs),
    ]);
    final messages = {for (final row in results[1]) row['id']: row};
    final tools = {for (final row in results[2]) row['id']: row};
    final events = <Object, List<Map<String, Object?>>>{};
    for (final row in results[0]) {
      events.putIfAbsent(row['run_id']!, () => []).add(row);
    }
    return {
      for (final run in runs)
        run['final_message_id']! as String: AgentTaskSummary(
          elapsedMilliseconds: run['elapsed_ms']! as int,
          stopped: run['status'] == 'cancelled',
          intermediateMessageIds: [
            for (final event
                in events[run['id']] ?? const <Map<String, Object?>>[])
              if (event['message_id'] != null &&
                  event['message_id'] != run['final_message_id'])
                event['message_id']! as String,
          ],
          activities: [
            for (final event
                in events[run['id']] ?? const <Map<String, Object?>>[])
              if (event['message_id'] != run['final_message_id'] ||
                  (run['status'] == 'cancelled' &&
                      event['kind'] == 'message' &&
                      messages[event['message_id']]!['text'] != ''))
                _activity(event, messages, tools),
          ],
        ),
    };
  }

  AgentTaskActivity _activity(
    Map<String, Object?> event,
    Map<Object?, Map<String, Object?>> messages,
    Map<Object?, Map<String, Object?>> tools,
  ) {
    if (event['kind'] == 'message') {
      return AgentTaskActivity(
        text: messages[event['message_id']]!['text']! as String,
      );
    }
    if (event['kind'] == 'tool') {
      final tool = tools[event['tool_call_id']]!;
      return AgentTaskActivity(
        text: tool['title']! as String,
        toolName: tool['name']! as String,
        requestJson: tool['arguments_json'] as String?,
        resultJson: tool['result_json'] as String?,
        status: AgentStepStatus.values.byName(tool['status']! as String),
      );
    }
    final status = event['legacy_status'] as String?;
    return AgentTaskActivity(
      text: event['legacy_text']! as String,
      status: status == null ? null : AgentStepStatus.values.byName(status),
    );
  }

  Future<List<AgentStep>> steps(String runId) async {
    final results = await Future.wait([
      database.query(
        'tool_calls',
        where: 'run_id = ?',
        whereArgs: [runId],
        orderBy: 'started_at, id',
      ),
      database.query(
        'run_events',
        where: 'run_id = ? AND kind = ?',
        whereArgs: [runId, 'legacy'],
        orderBy: 'id',
      ),
    ]);
    return [
      for (final row in results[0])
        AgentStep(
          toolName: row['name']! as String,
          title: row['title']! as String,
          requestJson: row['arguments_json'] as String?,
          resultJson: row['result_json'] as String?,
          status: AgentStepStatus.values.byName(row['status']! as String),
        ),
      for (final row in results[1])
        if (row['legacy_status'] != null)
          AgentStep(
            toolName: '',
            title: row['legacy_text']! as String,
            status: AgentStepStatus.values.byName(
              row['legacy_status']! as String,
            ),
          ),
    ];
  }

  Future<List<ConversationSearchResult>> search(
    String query,
    int offset,
  ) async {
    final rows = await database.query(
      'conversations',
      where: query.isEmpty
          ? null
          : 'instr(lower(title), ?) > 0 OR instr(lower(draft), ?) > 0 OR id IN '
                '(SELECT conversation_id FROM messages WHERE instr(lower(text), ?) > 0)',
      whereArgs: query.isEmpty ? null : [query, query, query],
      orderBy: 'pinned DESC, updated_at DESC, id DESC',
      limit: pageSize,
      offset: offset,
    );
    if (rows.isEmpty) return [];
    final hits = query.isEmpty
        ? <Map<String, Object?>>[]
        : await database.query(
            'messages',
            columns: ['conversation_id', 'text'],
            where:
                'conversation_id IN (${_slots(rows.length)}) AND instr(lower(text), ?) > 0',
            whereArgs: [...rows.map((row) => row['id']), query],
            groupBy: 'conversation_id',
          );
    final snippets = {
      for (final hit in hits) hit['conversation_id']: hit['text']! as String,
    };
    return rows.map((row) {
      final conversation = conversationFromRow(row);
      final text = conversation.draft.toLowerCase().contains(query)
          ? conversation.draft
          : snippets[conversation.id] ?? '';
      final index = text.toLowerCase().indexOf(query);
      final start = index > 16 ? index - 16 : 0;
      return (
        conversation: conversation,
        snippet:
            query.isEmpty || conversation.title.toLowerCase().contains(query)
            ? ''
            : '${start > 0 ? '…' : ''}${text.substring(start).replaceAll('\n', ' ')}',
      );
    }).toList();
  }
}

String _slots(int count) => List.filled(count, '?').join(',');
