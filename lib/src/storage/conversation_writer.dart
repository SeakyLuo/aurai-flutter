import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/agent_models.dart';
import '../features/chat/conversation.dart';
import 'conversation_rows.dart';

class ConversationWriter {
  ConversationWriter(this.database);
  final Database database;
  final Map<String, AgentMessage> _savedMessages = {};
  Future<void> _saving = Future.value();

  void remember(Iterable<AgentMessage> messages) {
    for (final message in messages) {
      _savedMessages[message.id] = message;
    }
  }

  Future<void> save(Conversation conversation, {bool makeActive = true}) {
    final header = conversationRow(conversation);
    final seenRunId = conversation.seenRunId;
    final contextSummary = conversation.contextSummary;
    final encodedSummary = contextSummary == null
        ? null
        : jsonEncode(contextSummary.toJson());
    final changed = conversation.messages
        .where((message) => !identical(_savedMessages[message.id], message))
        .toList();
    final messageRows = [
      for (final message in changed) messageRow(conversation.id, message),
    ];
    final imageRows = [
      for (var i = 0; i < conversation.draftImages.length; i++)
        attachmentRow(conversation.id, conversation.draftImages[i], i),
      for (final message in changed)
        for (var i = 0; i < message.images.length; i++)
          attachmentRow(
            conversation.id,
            message.images[i],
            i,
            messageId: message.id,
          ),
    ];
    final write = _saving.then((_) async {
      await database.transaction((txn) async {
        final batch = txn.batch();
        upsert(batch, 'conversations', header);
        if (seenRunId != null) {
          batch.insert('app_state', {
            'key': 'seen_run:${conversation.id}',
            'value': seenRunId,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        if (encodedSummary != null) {
          batch.insert('app_state', {
            'key': 'context_summary:${conversation.id}',
            'value': encodedSummary,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final row in messageRows) {
          upsert(batch, 'messages', row);
          if (row['run_id'] != null) {
            batch.insert('run_events', {
              'conversation_id': conversation.id,
              'run_id': row['run_id'],
              'kind': 'message',
              'message_id': row['id'],
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }
        batch.delete(
          'attachments',
          where: 'conversation_id = ? AND message_id IS NULL',
          whereArgs: [conversation.id],
        );
        for (final row in imageRows) {
          upsert(batch, 'attachments', row);
        }
        if (makeActive) {
          batch.insert('app_state', {
            'key': 'active_conversation',
            'value': conversation.id,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      });
      remember(changed);
    });
    // A failed write must not block later attempts; its caller still receives the error.
    _saving = write.catchError((Object error) {});
    return write;
  }

  void retain(Iterable<AgentMessage> messages) {
    _savedMessages.clear();
    remember(messages);
  }

  Future<void> flush() => _saving;

  static void upsert(Batch batch, String table, Map<String, Object?> row) {
    batch.insert(table, row, conflictAlgorithm: ConflictAlgorithm.ignore);
    batch.update(table, row, where: 'id = ?', whereArgs: [row['id']]);
  }
}
