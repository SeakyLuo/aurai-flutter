import '../html_games/html_game_store.dart';
import '../html_games/html_game.dart';
import '../domain/interactive_message.dart';
import '../domain/draft_mention.dart';
import 'conversation_visibility.dart';
import 'dart:convert';
import '../domain/message_quote.dart';
import 'group_list_preview.dart';
import '../domain/message_file.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/agent_models.dart';
import '../domain/message_sender.dart';
import '../domain/message_image.dart';
import '../features/chat/conversation.dart';
import 'conversation_rows.dart';
import 'protocol_history.dart';
import '../domain/model_provider.dart';

typedef ConversationSearchResult = ({
  Conversation conversation,
  String snippet,
  String? messageId,
  MessageSender? sender,
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
    ConversationKind? kind,
  }) async {
    final rows = await database.query(
      'conversations',
      where:
          '$visibleConversation AND $localUserConversation AND archived = ?${kind == null ? '' : ' AND kind = ?'}${after == null ? '' : ' AND (pinned < ? OR (pinned = ? AND (updated_at < ? OR (updated_at = ? AND id < ?))))'}',
      whereArgs: [
        archived ? 1 : 0,
        if (kind != null) kind.name,
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
        _loadDraftQuotes(values),
        _loadListCreationMembers(values),
        loadConversationListPreviews(database, values),
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

  Future<void> _loadListCreationMembers(
    List<Conversation> conversations,
  ) async {
    final ids = conversations
        .expand((value) => value.creationMemberIds)
        .toSet()
        .toList();
    if (ids.isEmpty) return;
    final rows = await database.query(
      'message_senders',
      where: 'id IN (${_slots(ids.length)})',
      whereArgs: ids,
    );
    final senders = {
      for (final row in rows) row['id'] as String: MessageSender.fromRow(row),
    };
    for (final conversation in conversations) {
      conversation.creationMembers = [
        for (final id in conversation.creationMemberIds) senders[id]!,
      ];
    }
  }

  Future<void> _loadDraftQuotes(List<Conversation> conversations) async {
    final quotes = conversations
        .map((c) => c.draftQuote)
        .whereType<MessageQuote>()
        .toList();
    if (quotes.isEmpty) return;
    final ids = quotes.map((q) => q.senderId).toSet();
    final rows = await database.query(
      'message_senders',
      columns: ['id', 'name'],
      where: 'id IN (${_slots(ids.length)})',
      whereArgs: ids.toList(),
    );
    final names = {for (final row in rows) row['id']: row['name'] as String};
    for (final quote in quotes) {
      quote.senderName = names[quote.senderId]!;
    }
  }

  Future<void> _loadCreationMembers(Conversation conversation) async {
    final ids = conversation.creationMemberIds;
    if (ids.isEmpty) return;
    final rows = await database.query(
      'message_senders',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    final senders = {
      for (final row in rows) row['id'] as String: MessageSender.fromRow(row),
    };
    conversation.creationMembers = [for (final id in ids) senders[id]!];
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
      _loadDraftQuotes([conversation]),
      _loadCreationMembers(conversation),
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
    if (conversation.kind == ConversationKind.direct &&
        conversation.activeRunId != null) {
      conversation.steps.addAll(await steps(conversation.activeRunId!));
    }
    if (conversation.kind == ConversationKind.direct &&
        conversation.runState == ChatRunState.failed &&
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
      for (final conversation in conversations) ...{
        'seen_run:${conversation.id}': conversation,
        'draft_mentions:${conversation.id}': conversation,
      },
    };
    final rows = await database.query(
      'app_state',
      where: 'key IN (${_slots(byKey.length)})',
      whereArgs: byKey.keys.toList(),
    );
    for (final row in rows) {
      final key = row['key'] as String;
      final conversation = byKey[key]!;
      if (key.startsWith('draft_mentions:')) {
        conversation.draftMentions.addAll(
          (jsonDecode(row['value'] as String) as List).map(
            (m) => DraftMention.fromJson(Map<String, dynamic>.from(m as Map)),
          ),
        );
      } else {
        conversation.seenRunId = row['value'] as String;
      }
    }
  }

  Future<List<AgentMessage>> messages(
    String conversationId, {
    AgentMessage? before,
    AgentMessage? after,
    String? throughMessageId,
    String? includeMessageId,
    int limit = messagePageSize,
    bool forModel = false,
    bool includeSystem = false,
    ModelConfig? modelConfig,
    String? afterCheckpoint,
  }) async {
    final selectionWhere =
        'conversation_id = ?${forModel
            ? "${includeSystem ? '' : " AND kind != 'system'"} AND kind != 'message_failure' AND NOT (role = 'assistant' AND text = '')"
            : includeMessageId == null
            ? " AND kind != 'commentary'"
            : " AND (kind != 'commentary' OR id = ?)"}${afterCheckpoint == null ? '' : ' AND created_at >= (SELECT created_at FROM messages WHERE id = ?)'}${before == null ? '' : ' AND (created_at < ? OR (created_at = ? AND id < ?))'}${after == null ? '' : ' AND (created_at > ? OR (created_at = ? AND id > ?))'}${throughMessageId == null ? '' : ' AND (created_at, id) <= (SELECT created_at, id FROM messages WHERE id = ?)'}';
    final selectionArgs = <Object?>[
      conversationId,
      if (!forModel && includeMessageId != null) includeMessageId,
      if (afterCheckpoint != null) afterCheckpoint,
      if (before != null) ...[
        before.createdAt.microsecondsSinceEpoch,
        before.createdAt.microsecondsSinceEpoch,
        before.id,
      ],
      if (after != null) ...[
        after.createdAt.microsecondsSinceEpoch,
        after.createdAt.microsecondsSinceEpoch,
        after.id,
      ],
      if (throughMessageId != null) throughMessageId,
    ];
    final order = after == null
        ? 'created_at DESC, id DESC'
        : 'created_at ASC, id ASC';
    final rows = await database.query(
      'messages',
      where: selectionWhere,
      whereArgs: selectionArgs,
      orderBy: order,
      limit: forModel ? null : limit,
    );
    final selectedMessages =
        'SELECT id FROM messages WHERE $selectionWhere ORDER BY $order LIMIT ?';
    final selectedArgs = [...selectionArgs, limit];
    if (rows.isEmpty) return [];
    final quotes = {
      for (final row in rows)
        if (row['quote_json'] != null)
          row['id']: MessageQuote.fromJson(
            (jsonDecode(row['quote_json'] as String) as Map)
                .cast<String, Object?>(),
          ),
    };
    final gameIds = rows
        .where((r) => r['kind'] == 'html_game')
        .map((r) => r['id'])
        .toList();
    final previews = gameIds.isEmpty || forModel
        ? <Map<String, Object?>>[]
        : await database.rawQuery(
            'SELECT message_id, title, preview, background_mode, display_mode, display_width, display_height, version, status, ${HtmlGameStore.retryColumn} FROM html_games WHERE message_id IN (${_slots(gameIds.length)})',
            gameIds,
          );
    final gameCards = {
      for (final row in previews) row['message_id']: HtmlGameCard.fromRow(row),
    };
    final senderIds = rows
        .map((row) => row['sender_id'] as String)
        .followedBy(quotes.values.map((q) => q.senderId))
        .toSet()
        .toList();
    final attachmentsAndSenders = await Future.wait([
      database.query(
        'attachments',
        where: forModel
            ? 'conversation_id = ? AND message_id IS NOT NULL'
            : 'message_id IN ($selectedMessages)',
        whereArgs: forModel ? [conversationId] : selectedArgs,
        orderBy: 'position',
      ),
      database.query(
        'message_senders',
        where: 'id IN (${_slots(senderIds.length)})',
        whereArgs: senderIds,
      ),
    ]);
    final images = attachmentsAndSenders[0];
    final senders = {
      for (final row in attachmentsAndSenders[1])
        row['id'] as String: MessageSender.fromRow(row),
    };
    for (final quote in quotes.values) {
      quote.senderName = senders[quote.senderId]!.name;
    }
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
    return (after == null ? rows.reversed : rows)
        .map(
          (row) => AgentMessage(
            id: row['id']! as String,
            isSystem: row['kind'] == 'system',
            isFailure: row['kind'] == 'message_failure',
            htmlGame: row['kind'] == 'html_game'
                ? (forModel
                      ? HtmlGameCard(title: row['text'] as String)
                      : gameCards[row['id']])
                : null,
            isGroupMessage:
                row['kind'] == 'group_message' ||
                row['kind'] == 'html_game' ||
                row['kind'] == 'message_failure',
            quote: quotes[row['id']],
            interactive: row['interactive_json'] == null
                ? null
                : InteractiveMessage.fromJson(
                    jsonDecode(row['interactive_json'] as String)
                        as Map<String, dynamic>,
                  ),
            role: AgentMessageRole.values.byName(row['role']! as String),
            senderId: row['sender_id'] as String,
            sender: senders[row['sender_id']]!,
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
        "final_message_id IN ($selectedMessages) AND elapsed_ms IS NOT NULL AND is_task = 1 AND conversation_id IN (SELECT id FROM conversations WHERE kind = 'direct')";
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
                  !const {
                    'group_message',
                    'html_game',
                  }.contains(messages[event['message_id']]!['kind']) &&
                  messages[event['message_id']]!['interactive_json'] == null &&
                  event['message_id'] != run['final_message_id'])
                event['message_id']! as String,
          ],
          activities: [
            for (final event
                in events[run['id']] ?? const <Map<String, Object?>>[])
              if ((event['message_id'] == null ||
                      messages[event['message_id']]!['kind'] !=
                          'group_message') &&
                  (event['tool_call_id'] == null ||
                      !const {
                        'sendGroupMessages',
                        'sendGroupMessage',
                      }.contains(tools[event['tool_call_id']]!['name'])) &&
                  (event['message_id'] != run['final_message_id'] ||
                      (run['status'] == 'cancelled' &&
                          event['kind'] == 'message' &&
                          messages[event['message_id']]!['text'] != '')))
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
        messageId: event['message_id'] as String,
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
    if (query.isEmpty) {
      final rows = await database.query(
        'conversations',
        where:
            "$visibleConversation AND $localUserConversation AND mode = 'normal'",
        orderBy: 'pinned DESC, updated_at DESC, id DESC',
        limit: pageSize,
        offset: offset,
      );
      return [
        for (final row in rows)
          (
            conversation: conversationFromRow(row),
            messageId: null,
            sender: null,
            snippet: '',
          ),
      ];
    }
    final hits = await database.rawQuery(
      '''SELECT id AS message_id, conversation_id, text, sender_id, created_at, id AS sort_id
         FROM messages WHERE kind != 'system' AND conversation_id IN (SELECT id FROM conversations WHERE $localUserConversation AND mode = 'normal') AND instr(lower(text), ?) > 0
         UNION ALL
         SELECT NULL AS message_id, id AS conversation_id,
           CASE WHEN instr(lower(draft), ?) > 0 THEN draft ELSE '' END AS text,
           NULL AS sender_id, created_at, id AS sort_id
         FROM conversations
         WHERE $visibleConversation AND $localUserConversation AND mode = 'normal' AND (instr(lower(title), ?) > 0 OR instr(lower(draft), ?) > 0)
           AND id NOT IN (
             SELECT conversation_id FROM messages WHERE kind != 'system' AND instr(lower(text), ?) > 0
           )
         ORDER BY created_at DESC, sort_id DESC
         LIMIT ? OFFSET ?''',
      [query, query, query, query, query, pageSize, offset],
    );
    if (hits.isEmpty) return [];
    final ids = hits.map((hit) => hit['conversation_id'] as String).toSet();
    final senderIds = hits
        .map((hit) => hit['sender_id'])
        .whereType<String>()
        .toSet();
    final related = await Future.wait([
      database.query(
        'conversations',
        where: 'id IN (${_slots(ids.length)})',
        whereArgs: ids.toList(),
      ),
      if (senderIds.isNotEmpty)
        database.query(
          'message_senders',
          where: 'id IN (${_slots(senderIds.length)})',
          whereArgs: senderIds.toList(),
        ),
    ]);
    final conversations = {
      for (final row in related.first)
        row['id'] as String: conversationFromRow(row),
    };
    final senders = {
      if (senderIds.isNotEmpty)
        for (final row in related[1])
          row['id'] as String: MessageSender.fromRow(row),
    };
    return hits.map((hit) {
      final text = hit['text'] as String;
      final index = text.toLowerCase().indexOf(query);
      final start = index > 4 ? index - 4 : 0;
      return (
        conversation: conversations[hit['conversation_id']]!,
        messageId: hit['message_id'] as String?,
        sender: hit['sender_id'] == null ? null : senders[hit['sender_id']]!,
        snippet:
            '${start > 0 ? '…' : ''}${text.substring(start).replaceAll('\n', ' ')}',
      );
    }).toList();
  }
}

String _slots(int count) => List.filled(count, '?').join(',');
