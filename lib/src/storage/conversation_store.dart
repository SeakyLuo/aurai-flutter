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

  Future<String?> initialize(
    String imageDirectory,
    Future<String?> Function() loadLegacy,
    Future<void> Function() clearLegacy,
  ) async {
    database = await openConversationDatabase();
    try {
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
      await database.update('conversations', {
        'archived': 1,
      }, where: "mode != 'normal' AND archived = 0");
      await database.delete(
        'app_state',
        where:
            "key = 'active_conversation' AND value IN (SELECT id FROM conversations WHERE mode != 'normal')",
      );
      await database.transaction((txn) async {
        final batch = txn.batch();
        batch.update(
          'conversations',
          {'run_state': 'interrupted'},
          where: 'run_state IN (?, ?)',
          whereArgs: ['running', 'stopping'],
        );
        batch.update(
          'agent_runs',
          {'status': 'interrupted'},
          where: 'status = ?',
          whereArgs: ['running'],
        );
        batch.update(
          'model_turns',
          {'status': 'interrupted'},
          where: 'status = ?',
          whereArgs: ['running'],
        );
        batch.update(
          'tool_calls',
          {'status': 'cancelled'},
          where: 'status = ?',
          whereArgs: ['running'],
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
            "kind = 'direct' AND id NOT IN (SELECT conversation_id FROM direct_conversation_pairs) AND message_count = 0 AND draft = '' AND pending_goal IS NULL AND NOT EXISTS (SELECT 1 FROM attachments WHERE conversation_id = conversations.id)",
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

  Future<void> removeDraftConversation(String id) async {
    await writer.flush();
    await database.delete(
      'conversations',
      where: "id = ? AND kind = 'direct' AND message_count = 0",
      whereArgs: [id],
    );
    await selectNewConversation();
  }

  Future<Conversation> load(
    String id, {
    int messageLimit = ConversationReader.messagePageSize,
  }) async {
    await writer.flush();
    final conversation = await reader.load(id, messageLimit: messageLimit);
    final rows = await database.query(
      'app_state',
      where: 'key = ?',
      whereArgs: ['context_summary:$id'],
    );
    if (rows.isNotEmpty) {
      conversation.contextSummary = ContextSummary.fromJson(
        (jsonDecode(rows.single['value']! as String) as Map)
            .cast<String, Object?>(),
      );
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
        where: 'key IN (?, ?)',
        whereArgs: ['context_summary:${removed.id}', 'seen_run:${removed.id}'],
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
