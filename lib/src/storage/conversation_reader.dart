import 'group_unread_messages.dart';
import 'group_member_details.dart';
import '../html_games/html_store.dart';
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
import '../domain/miniapp_share.dart';
import '../domain/message_sender.dart';
import '../domain/message_image.dart';
import '../domain/message_quick_reply.dart';
import '../features/chat/conversation.dart';
import 'conversation_rows.dart';
import 'protocol_history.dart';
import '../domain/model_provider.dart';

part 'conversation_search_reader.dart';

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
    int limit = pageSize,
    bool archived = false,
    ConversationKind? kind,
  }) async {
    final rows = await database.query(
      'conversations',
      where:
          '$visibleConversation AND $localUserConversation AND archived = ?${kind == null ? '' : ' AND kind = ?'}${after == null ? '' : ' AND (pinned < ? OR (pinned = ? AND (MAX(updated_at, draft_updated_at) < ? OR (MAX(updated_at, draft_updated_at) = ? AND id < ?))))'}',
      whereArgs: [
        archived ? 1 : 0,
        if (kind != null) kind.name,
        if (after != null) ...[
          after.isPinned ? 1 : 0,
          after.isPinned ? 1 : 0,
          after.listUpdatedAt.microsecondsSinceEpoch,
          after.listUpdatedAt.microsecondsSinceEpoch,
          after.id,
        ],
      ],
      orderBy: 'pinned DESC, MAX(updated_at, draft_updated_at) DESC, id DESC',
      limit: limit,
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
        loadPendingQuestionPreviews(database, values),
        GroupUnreadMessages(database).load(values),
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
    ids.add(MessageSender.localUser.id);
    final rows = await database.query(
      'message_senders',
      where: 'id IN (${_slots(ids.length)})',
      whereArgs: ids,
    );
    final senders = {
      for (final row in rows) row['id'] as String: MessageSender.fromRow(row),
    };
    for (final conversation in conversations) {
      conversation.creationUserName = senders[MessageSender.localUser.id]!.name;
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
    final ids = [...conversation.creationMemberIds];
    if (ids.isEmpty) return;
    ids.add(MessageSender.localUser.id);
    final rows = await database.query(
      'message_senders',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    final senders = {
      for (final row in rows) row['id'] as String: MessageSender.fromRow(row),
    };
    conversation.creationUserName = senders[MessageSender.localUser.id]!.name;
    conversation.creationMembers = [
      for (final id in conversation.creationMemberIds) senders[id]!,
    ];
  }

  Future<void> _loadNoticeMembers(Conversation conversation) async {
    if (conversation.kind != ConversationKind.group) return;
    final rows = await database.query(
      'message_senders',
      where:
          'id IN (SELECT sender_id FROM conversation_members WHERE conversation_id = ?)',
      whereArgs: [conversation.id],
    );
    final senders = {
      for (final row in rows) row['id'] as String: MessageSender.fromRow(row),
    };
    conversation.noticeMembers.addAll(
      await GroupMemberDetailsStore(
        database,
      ).applyNames(conversation.id, senders),
    );
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
      _loadNoticeMembers(conversation),
      GroupUnreadMessages(database).load([conversation]),
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
    if (conversation.kind == ConversationKind.direct) {
      final unfinishedRuns = await _loadUnfinishedToolSteps(conversation);
      final run = unfinishedRuns
          .where((row) => row['id'] == conversation.activeRunId)
          .firstOrNull;
      if (run != null && run['elapsed_ms'] != null) {
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

  Future<List<Map<String, Object?>>> _loadUnfinishedToolSteps(
    Conversation conversation,
  ) async {
    final runs = await database.query(
      'agent_runs',
      where:
          "parent_run_id IS NULL AND conversation_id = ? AND (status IN ('failed', 'cancelled', 'interrupted') OR (status = 'completed' AND (final_message_id IS NULL OR final_message_id NOT IN (SELECT id FROM messages WHERE kind = 'final' AND interactive_json IS NULL AND text != '')))) AND (status = 'cancelled' OR id = ? OR id IN (SELECT run_id FROM tool_calls))",
      whereArgs: [conversation.id, conversation.activeRunId],
      orderBy: 'started_at, id',
    );
    if (runs.isEmpty) return runs;
    for (final run in runs) {
      if (run['elapsed_ms'] case final int elapsedMilliseconds) {
        conversation.unfinishedRunElapsed[run['id']! as String] = Duration(
          milliseconds: elapsedMilliseconds,
        );
        if (run['status'] == 'cancelled') {
          conversation.cancelledRunMessages[run['id']! as String] =
              run['user_message_id']! as String;
        }
      }
    }
    final ids = runs.map((run) => run['id']).toList();
    final results = await Future.wait([
      database.query(
        'run_events',
        where: 'run_id IN (${_slots(ids.length)})',
        whereArgs: ids,
        orderBy: 'id',
      ),
      database.query(
        'tool_calls',
        where: 'run_id IN (${_slots(ids.length)})',
        whereArgs: ids,
      ),
    ]);
    final events = results[0];
    final tools = {for (final row in results[1]) row['id']: row};
    final afterMessageIds = {
      for (final run in runs) run['id']!: run['user_message_id']! as String,
    };
    final visibleMessageIds = conversation.messages.map((m) => m.id).toSet();
    for (final event in events) {
      final runId = event['run_id']! as String;
      if (event['kind'] == 'message') {
        if (visibleMessageIds.contains(event['message_id'])) {
          afterMessageIds[runId] = event['message_id']! as String;
        }
      } else if (event['kind'] == 'tool') {
        final tool = tools[event['tool_call_id']]!;
        conversation.liveToolSteps.add((
          runId: runId,
          afterMessageId: afterMessageIds[runId]!,
          step: AgentStep(
            toolName: tool['name']! as String,
            title: tool['title']! as String,
            startedAt: DateTime.fromMicrosecondsSinceEpoch(
              tool['started_at']! as int,
            ),
            finishedAt: tool['finished_at'] == null
                ? null
                : DateTime.fromMicrosecondsSinceEpoch(
                    tool['finished_at']! as int,
                  ),
            requestJson: tool['arguments_json'] as String?,
            resultJson: tool['result_json'] as String?,
            status: AgentStepStatus.values.byName(tool['status']! as String),
          ),
        ));
      }
    }
    return runs;
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
    const richReply =
        "run_id IN (SELECT run_id FROM messages WHERE conversation_id = ? AND run_id IS NOT NULL AND (interactive_json IS NOT NULL OR kind = 'html_game' OR (kind = 'assistant' AND model_turn_id IS NULL)))";
    final selectionWhere =
        'conversation_id = ?${forModel
            ? "${includeSystem ? '' : " AND kind != 'system'"} AND kind NOT IN ('message_failure', 'reasoning') AND NOT (role = 'assistant' AND text = '')"
            : includeMessageId == null
            ? " AND kind != 'quick_reply' AND (kind != 'commentary' OR $richReply)"
            : " AND kind != 'quick_reply' AND (kind != 'commentary' OR $richReply OR id = ?)"}${afterCheckpoint == null ? '' : ' AND created_at >= (SELECT created_at FROM messages WHERE id = ?)'}${before == null ? '' : ' AND (created_at < ? OR (created_at = ? AND id < ?))'}${after == null ? '' : ' AND (created_at > ? OR (created_at = ? AND id > ?))'}${throughMessageId == null ? '' : ' AND (created_at, id) <= (SELECT created_at, id FROM messages WHERE id = ?)'}';
    final selectionArgs = <Object?>[
      conversationId,
      if (!forModel) conversationId,
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
            'SELECT message_id, app_id, title, preview, preview_theme, background_mode, display_mode, display_width, display_height, measured_width, measured_height, measured_scale, measured_version, version, status, ${HtmlStore.retryColumn} FROM html_games WHERE message_id IN (${_slots(gameIds.length)})',
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
    final pageRuns = {
      for (final row in rows)
        if (row['run_id'] != null) row['run_id'],
    };
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
        where: forModel
            ? 'id IN (${_slots(senderIds.length)})'
            : 'id IN (${_slots(senderIds.length)}) OR id IN (SELECT actor_id FROM message_quick_replies WHERE parent_message_id IN ($selectedMessages))',
        whereArgs: [...senderIds, if (!forModel) ...selectedArgs],
      ),
      if (!forModel && pageRuns.isNotEmpty)
        database.query(
          'messages',
          distinct: true,
          columns: ['run_id'],
          where:
              'conversation_id = ? AND run_id IN (${_slots(pageRuns.length)}) '
              "AND (interactive_json IS NOT NULL OR kind = 'html_game' OR (kind = 'assistant' AND model_turn_id IS NULL))",
          whereArgs: [conversationId, ...pageRuns],
        )
      else
        Future.value(<Map<String, Object?>>[]),
      if (!forModel)
        database.query(
          'message_quick_replies',
          where: 'parent_message_id IN ($selectedMessages)',
          whereArgs: selectedArgs,
        )
      else
        Future.value(<Map<String, Object?>>[]),
      if (!forModel)
        database.query(
          'messages',
          where:
              'id IN (SELECT message_id FROM message_quick_replies WHERE parent_message_id IN ($selectedMessages))',
          whereArgs: selectedArgs,
          orderBy: 'created_at, id',
        )
      else
        Future.value(<Map<String, Object?>>[]),
    ]);
    final richRuns = attachmentsAndSenders[2]
        .map((row) => row['run_id'])
        .toSet();
    final images = attachmentsAndSenders[0];
    final senders = await GroupMemberDetailsStore(database)
        .applyNames(conversationId, {
          for (final row in attachmentsAndSenders[1])
            row['id'] as String: MessageSender.fromRow(row),
        });
    final quickReplyRelations = {
      for (final row in attachmentsAndSenders[3])
        row['message_id'] as String: row,
    };
    final quickReplies = <String, List<MessageQuickReply>>{};
    for (final row in attachmentsAndSenders[4]) {
      final relation = quickReplyRelations[row['id']]!;
      quickReplies
          .putIfAbsent(relation['parent_message_id'] as String, () => [])
          .add(
            MessageQuickReply(
              id: row['id'] as String,
              senderId: relation['actor_id'] as String,
              senderName: senders[relation['actor_id']]!.name,
              key: relation['reply_key'] as String,
              createdAt: DateTime.fromMicrosecondsSinceEpoch(
                row['created_at'] as int,
              ),
            ),
          );
    }
    for (final quote in quotes.values) {
      quote.senderName = senders[quote.senderId]!.name;
    }
    final imageMap = <String, List<MessageImage>>{};
    final fileMap = <String, List<MessageFile>>{};
    for (final image in images) {
      if (image['kind'] == 'miniapp_media') continue;
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
            miniappShare: row['miniapp_share_json'] == null
                ? null
                : MiniappShare.fromJson(
                    (jsonDecode(row['miniapp_share_json'] as String) as Map)
                        .cast<String, Object?>(),
                    imageDirectory,
                  ),
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
            markdown: row['markdown'] == 1,
            senderId: row['sender_id'] as String,
            sender: senders[row['sender_id']]!,
            text: row['text']! as String,
            createdAt: DateTime.fromMicrosecondsSinceEpoch(
              row['created_at']! as int,
            ),
            images: imageMap[row['id']] ?? const [],
            files: fileMap[row['id']] ?? const [],
            runId: row['run_id'] as String?,
            isRichReply: richRuns.contains(row['run_id']),
            isReasoning: row['kind'] == 'reasoning',
            modelTurnId: row['model_turn_id'] as String?,
            taskSummary: summaries[row['id']],
            responseInput: protocol[row['id']],
            quickReplies: quickReplies[row['id']] ?? const [],
          ),
        )
        .toList();
  }

  Future<Map<String, AgentTaskSummary>> _summaries(
    String selectedMessages,
    List<Object?> selectedArgs,
  ) async {
    final runWhere =
        "status IN ('completed', 'failed', 'interrupted') AND final_message_id IN ($selectedMessages) AND final_message_id IN (SELECT id FROM messages WHERE kind = 'final' AND interactive_json IS NULL AND text != '') AND elapsed_ms IS NOT NULL AND (is_task = 1 OR id IN (SELECT run_id FROM messages WHERE kind = 'reasoning')) AND conversation_id IN (SELECT id FROM conversations WHERE kind = 'direct')";
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
      database.query(
        'app_state',
        where: 'key IN (${_slots(runs.length)})',
        whereArgs: [for (final run in runs) 'git_task:${run['id']}'],
      ),
    ]);
    final messages = {for (final row in results[1]) row['id']: row};
    final tools = {for (final row in results[2]) row['id']: row};
    final gitChanges = {
      for (final row in results[3])
        (row['key'] as String).substring(
          'git_task:'.length,
        ): ProjectGitTaskChanges.fromJson(
          (jsonDecode(row['value'] as String) as Map).cast<String, Object?>(),
        ),
    };
    final events = <Object, List<Map<String, Object?>>>{};
    for (final row in results[0]) {
      events.putIfAbsent(row['run_id']!, () => []).add(row);
    }
    return {
      for (final run in runs)
        run['final_message_id']! as String: AgentTaskSummary(
          elapsedMilliseconds: run['elapsed_ms']! as int,
          isTask: run['is_task'] == 1,
          stopped: run['status'] == 'cancelled',
          intermediateMessageIds:
              const {
                    'completed',
                    'failed',
                    'interrupted',
                  }.contains(run['status']) &&
                  messages[run['final_message_id']]!['kind'] == 'final' &&
                  messages[run['final_message_id']]!['interactive_json'] ==
                      null &&
                  (messages[run['final_message_id']]!['text'] as String)
                      .isNotEmpty
              ? [
                  for (final event
                      in events[run['id']] ?? const <Map<String, Object?>>[])
                    if (event['message_id'] != null &&
                        !const {
                          'group_message',
                          'html_game',
                        }.contains(messages[event['message_id']]!['kind']) &&
                        messages[event['message_id']]!['interactive_json'] ==
                            null &&
                        event['message_id'] != run['final_message_id'])
                      event['message_id']! as String,
                ]
              : const [],
          activities: [
            for (final event
                in events[run['id']] ?? const <Map<String, Object?>>[])
              if (((const {
                            'completed',
                            'failed',
                            'interrupted',
                          }.contains(run['status']) &&
                          messages[run['final_message_id']]!['kind'] ==
                              'final' &&
                          messages[run['final_message_id']]!['interactive_json'] ==
                              null &&
                          (messages[run['final_message_id']]!['text'] as String)
                              .isNotEmpty) ||
                      event['tool_call_id'] != null) &&
                  (event['message_id'] == null ||
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
          gitChanges: gitChanges[run['id']]?.fileCount == 0
              ? null
              : gitChanges[run['id']],
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
        isReasoning: messages[event['message_id']]!['kind'] == 'reasoning',
      );
    }
    if (event['kind'] == 'tool') {
      final tool = tools[event['tool_call_id']]!;
      return AgentTaskActivity(
        text: tool['title']! as String,
        startedAt: DateTime.fromMicrosecondsSinceEpoch(
          tool['started_at']! as int,
        ),
        finishedAt: tool['finished_at'] == null
            ? null
            : DateTime.fromMicrosecondsSinceEpoch(tool['finished_at']! as int),
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
          startedAt: DateTime.fromMicrosecondsSinceEpoch(
            row['started_at']! as int,
          ),
          finishedAt: row['finished_at'] == null
              ? null
              : DateTime.fromMicrosecondsSinceEpoch(row['finished_at']! as int),
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
}

String _slots(int count) => List.filled(count, '?').join(',');
