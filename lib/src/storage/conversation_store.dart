import 'group_unread_messages.dart';
import 'contact_store.dart';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/agent_models.dart';
import '../domain/context_summary.dart';
import '../features/chat/conversation.dart';
import 'agent_run_store.dart';
import 'group_chat_store.dart';
import 'conversation_database.dart';
import 'conversation_migration.dart';
import 'conversation_reader.dart';
import 'conversation_rows.dart';
import 'conversation_writer.dart';

export 'conversation_reader.dart' show ConversationSearchResult;

class ConversationStore {
  late final Database database;
  late final ConversationReader reader;
  late final ConversationWriter writer;
  late final AgentRunStore runs;
  late final GroupChatStore groups;
  List<Map<String, Object?>> startupRuns = const [];

  Future<String?> earliestGroupContextCheckpoint(
    Conversation conversation,
    Iterable<String> senderIds,
  ) async {
    final summaries = [
      conversation.contextSummary,
      for (final senderId in senderIds)
        conversation.privateContextSummaries[senderId],
    ];
    if (summaries.any((summary) => summary == null)) return null;
    final ids = summaries
        .cast<ContextSummary>()
        .map((summary) => summary.throughMessageId)
        .toList();
    final rows = await database.query(
      'messages',
      columns: ['id'],
      where: 'id IN (${List.filled(ids.length, '?').join(', ')})',
      whereArgs: ids,
      orderBy: 'created_at, id',
      limit: 1,
    );
    return rows.single['id']! as String;
  }

  Future<String?> initialize(
    String imageDirectory,
    Future<String?> Function() loadLegacy,
    Future<void> Function() clearLegacy,
  ) async {
    database = await openConversationDatabase();
    try {
      await ContactStore(database).loadLocalNames();
      reader = ConversationReader(database, imageDirectory);
      writer = ConversationWriter(database);
      runs = AgentRunStore(database);
      groups = GroupChatStore(database);
      final initialized = await database.query(
        'app_state',
        where: 'key = ?',
        whereArgs: ['initialized'],
      );
      if (initialized.isEmpty) {
        await migrateConversations(
          database,
          await loadLegacy(),
          imageDirectory,
        );
      }
      await clearLegacy();
      await GroupUnreadMessages(database).initialize();
      await database.update('conversations', {
        'archived': 1,
      }, where: "mode != 'normal' AND archived = 0");
      await database.delete(
        'app_state',
        where:
            "key = 'active_conversation' AND value IN (SELECT id FROM conversations WHERE mode != 'normal')",
      );
      final interruptedAt = DateTime.now().microsecondsSinceEpoch;
      await database.transaction((txn) async {
        final candidates = await txn.query(
          'agent_runs',
          where:
              "parent_run_id IS NULL AND (status = 'running' OR "
              "(status = 'interrupted' AND id IN (SELECT value FROM json_each("
              "(SELECT value FROM app_state WHERE key = 'startup_run_recovery'))))) "
              "AND NOT EXISTS (SELECT 1 FROM agent_runs newer WHERE newer.parent_run_id IS NULL "
              "AND newer.conversation_id = agent_runs.conversation_id AND newer.sender_id = agent_runs.sender_id "
              "AND (newer.started_at > agent_runs.started_at OR (newer.started_at = agent_runs.started_at AND newer.id > agent_runs.id))) "
              "AND conversation_id IN (SELECT id FROM conversations WHERE archived = 0 "
              "AND mode = 'normal' AND run_state != 'stopping')",
          orderBy: 'started_at DESC, id DESC',
        );
        final owners = <String>{};
        startupRuns = candidates
            .where(
              (run) =>
                  owners.add('${run['conversation_id']}:${run['sender_id']}'),
            )
            .toList();
        final batch = txn.batch();
        batch.insert('app_state', {
          'key': 'startup_run_recovery',
          'value': jsonEncode(startupRuns.map((run) => run['id']).toList()),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        batch.rawUpdate(
          r"UPDATE private_task_state SET state_json = json_remove(state_json, '$.runningSince') WHERE json_extract(state_json, '$.status') = 'active'",
        );
        batch.rawUpdate(
          r"UPDATE private_task_state SET state_json = json_set(state_json, '$.status', 'paused', '$.reason', '执行已中断，等待继续') WHERE json_extract(state_json, '$.status') = 'active' AND NOT EXISTS (SELECT 1 FROM agent_runs WHERE id IN (SELECT value FROM json_each(?)) AND conversation_id = private_task_state.conversation_id AND sender_id = private_task_state.sender_id)",
          [jsonEncode(startupRuns.map((run) => run['id']).toList())],
        );
        batch.update(
          'conversations',
          {'run_state': 'interrupted'},
          where: 'run_state IN (?, ?)',
          whereArgs: ['running', 'stopping'],
        );
        batch.rawUpdate(
          'UPDATE agent_runs SET status = ?, finished_at = ?, elapsed_ms = (? - started_at) / 1000 WHERE status = ?',
          ['interrupted', interruptedAt, interruptedAt, 'running'],
        );
        batch.rawUpdate(
          "UPDATE agent_runs SET final_message_id = (SELECT id FROM messages WHERE run_id = agent_runs.id AND kind NOT IN ('system', 'quick_reply') ORDER BY created_at DESC, id DESC LIMIT 1) WHERE status IN ('failed', 'interrupted') AND final_message_id IS NULL",
        );
        batch.update(
          'model_turns',
          {'status': 'interrupted'},
          where: 'status = ?',
          whereArgs: ['running'],
        );
        batch.rawUpdate(
          r"""UPDATE tool_calls
          SET result_json = json_set(result_json, '$.pending', json('false'), '$.interrupted', json('true'),
            '$.message', '执行已中断；已完成的操作不会撤销。继续前必须核实已有结果，不得直接重放外部写入。'),
            result_status = 'cancelled'
          WHERE status = 'running' AND json_extract(result_json, '$.pending') = 1""",
        );
        batch.update(
          'tool_calls',
          {'status': 'cancelled'},
          where: 'status = ?',
          whereArgs: ['running'],
        );
        // Task cards are persisted messages; interrupted executions must not
        // leave their last published status permanently running after restart.
        batch.rawUpdate(
          r"""UPDATE messages SET interactive_json = json_set(interactive_json,
            '$.participation._taskCard.status', 'cancelled',
            '$.revision', json_extract(interactive_json, '$.revision') + 1)
          WHERE json_extract(interactive_json, '$.participation._taskCard.status') = 'running'""",
        );
        batch.update(
          'tool_approvals',
          {'decision': 'interrupted'},
          where: 'decision = ?',
          whereArgs: ['pending'],
        );
        await batch.commit(noResult: true);
      });
      await database.delete(
        'conversations',
        where:
            "kind = 'direct' AND personal_chat = 0 AND id NOT IN (SELECT conversation_id FROM direct_conversation_pairs) AND message_count = 0 AND draft = '' AND pending_goal IS NULL AND NOT EXISTS (SELECT 1 FROM attachments WHERE conversation_id = conversations.id) AND NOT EXISTS (SELECT 1 FROM agent_runs WHERE conversation_id = conversations.id)",
      );
      await database.delete(
        'app_state',
        where:
            "key = 'active_conversation' AND NOT EXISTS (SELECT 1 FROM conversations WHERE id = app_state.value)",
      );
      final active = await database.query(
        'app_state',
        where: 'key = ?',
        whereArgs: ['active_conversation'],
      );
      return active.isEmpty ? null : active.single['value']! as String;
    } on Object {
      await database.close();
      rethrow;
    }
  }

  Future<void> selectNewConversation() async {
    await writer.flush();
    await database.delete(
      'app_state',
      where: 'key = ?',
      whereArgs: ['active_conversation'],
    );
  }

  Future<bool> hasMessages(String id) async => (await database.query(
    'conversations',
    columns: ['id'],
    where: 'id = ? AND message_count > 0',
    whereArgs: [id],
    limit: 1,
  )).isNotEmpty;

  Future<bool> hasConversation(String id) async => (await database.query(
    'conversations',
    columns: ['id'],
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  )).isNotEmpty;

  Future<void> removeDraftConversation(String id) async {
    await writer.flush();
    await database.delete(
      'conversations',
      where:
          "id = ? AND kind = 'direct' AND personal_chat = 0 AND message_count = 0 AND NOT EXISTS (SELECT 1 FROM agent_runs WHERE conversation_id = conversations.id)",
      whereArgs: [id],
    );
    await database.delete(
      'app_state',
      where: 'key = ? AND value = ?',
      whereArgs: ['active_conversation', id],
    );
  }

  Future<Conversation> load(
    String id, {
    int messageLimit = ConversationReader.messagePageSize,
  }) async {
    await writer.flush();
    final conversation = await reader.load(id, messageLimit: messageLimit);
    final rows = await database.query(
      'app_state',
      where: 'key = ? OR key LIKE ?',
      whereArgs: ['context_summary:$id', 'context_summary:$id:%'],
    );
    for (final row in rows) {
      final summary = ContextSummary.fromJson(
        (jsonDecode(row['value']! as String) as Map).cast<String, Object?>(),
      );
      final key = row['key']! as String;
      if (key == 'context_summary:$id') {
        conversation.contextSummary = summary;
      } else {
        conversation.privateContextSummaries[key.substring(
              'context_summary:$id:'.length,
            )] =
            summary;
      }
    }
    writer.remember(conversation.messages);
    return conversation;
  }

  Future<List<AgentMessage>> earlierMessages(Conversation conversation) async {
    final messages = await reader.messages(
      conversation.id,
      before: conversation.messages.first,
    );
    writer.remember(messages);
    return messages;
  }

  Future<void> delete(Conversation removed, Conversation replacement) async {
    await writer.flush();
    await database.transaction((txn) async {
      final batch = txn.batch();
      if (replacement.messageCount > 0) {
        ConversationWriter.upsert(
          batch,
          'conversations',
          conversationRow(replacement),
        );
      }
      batch.delete('conversations', where: 'id = ?', whereArgs: [removed.id]);
      batch.delete(
        'app_state',
        where: 'key IN (?, ?, ?) OR key = ? OR key LIKE ?',
        whereArgs: [
          'seen_run:${removed.id}',
          'group_read:${removed.id}',
          'pending_message_queue:${removed.id}',
          'context_summary:${removed.id}',
          'context_summary:${removed.id}:%',
        ],
      );
      if (replacement.messageCount > 0) {
        batch.insert('app_state', {
          'key': 'active_conversation',
          'value': replacement.id,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        batch.delete(
          'app_state',
          where: 'key = ?',
          whereArgs: ['active_conversation'],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<String>> attachmentPaths(String conversationId) async =>
      (await database.query(
        'attachments',
        columns: ['file_name'],
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
      )).map((row) => '${reader.imageDirectory}/${row['file_name']}').toList();
}
