import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../domain/agent_models.dart';
import '../domain/context_summary.dart';
import '../features/chat/conversation.dart';
import 'conversation_rows.dart';
import 'new_conversation_draft.dart';
import 'group_participation.dart';

class ConversationWriter {
  ConversationWriter(this.database);
  final Database database;
  final _draftStore = NewConversationDraft();
  final Map<String, AgentMessage> _savedMessages = {};
  Future<void> _saving = Future.value();

  Future<void> mutate(Future<void> Function() action) {
    final write = _saving.then((_) => action());
    _saving = write.catchError((Object _) {});
    return write;
  }

  void remember(Iterable<AgentMessage> messages) {
    for (final message in messages) {
      _savedMessages[message.id] = message;
    }
  }

  Future<void> save(
    Conversation conversation, {
    bool makeActive = true,
    bool saveDraft = false,
    bool saveRuntime = false,
    bool saveMessages = true,
    Map<String, List<String>> recipients = const {},
    ({String senderId, bool paused})? participation,
  }) {
    if (conversation.kind == ConversationKind.direct &&
        conversation.messageCount == 0 &&
        conversation.messages.isEmpty &&
        !conversation.isTemporary &&
        !conversation.isStored) {
      return _draftStore.save(conversation);
    }
    final header = conversationRow(conversation);
    final mentions = jsonEncode(
      conversation.draftMentions.map((m) => m.toJson()).toList(),
    );
    final changed = saveMessages
        ? conversation.messages
              .where(
                (message) => !identical(_savedMessages[message.id], message),
              )
              .toList()
        : <AgentMessage>[];
    final messageRows = [
      for (final message in changed) messageRow(conversation.id, message),
    ];
    final imageRows = [
      if (saveDraft)
        for (var i = 0; i < conversation.draftFiles.length; i++)
          fileAttachmentRow(conversation.id, conversation.draftFiles[i], i),
      for (final message in changed)
        for (var i = 0; i < message.files.length; i++)
          fileAttachmentRow(
            conversation.id,
            message.files[i],
            i,
            messageId: message.id,
          ),
      if (saveDraft)
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
        // A queued snapshot must never restore a recalled message or its attachments.
        final terminalRows = messageRows.isEmpty
            ? <Map<String, Object?>>[]
            : await txn.query(
                'messages',
                columns: ['id'],
                where:
                    "conversation_id = ? AND kind = 'system' AND id IN (SELECT value FROM json_each(?))",
                whereArgs: [
                  conversation.id,
                  jsonEncode(messageRows.map((row) => row['id']).toList()),
                ],
              );
        final terminalIds = terminalRows.map((row) => row['id']).toSet();
        final batch = txn.batch();
        batch.insert(
          'conversations',
          header,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (saveDraft) {
          batch.update(
            'conversations',
            {
              'draft': header['draft'],
              'draft_quote_json': header['draft_quote_json'],
            },
            where: 'id = ?',
            whereArgs: [conversation.id],
          );
          batch.insert('app_state', {
            'key': 'draft_mentions:${conversation.id}',
            'value': mentions,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        if (saveRuntime) {
          final runtime = {
            for (final key in ['pending_goal', 'run_state', 'error_detail'])
              key: header[key],
          };
          if (conversation.kind == ConversationKind.group) {
            batch.update(
              'conversations',
              runtime,
              where: 'id = ?',
              whereArgs: [conversation.id],
            );
          }
          batch.update(
            'conversations',
            {
              if (conversation.kind != ConversationKind.group) ...runtime,
              'active_run_id': header['active_run_id'],
            },
            where:
                "id = ? AND (active_run_id IS NULL OR active_run_id = ? OR (SELECT started_at FROM agent_runs WHERE id = ?) > (SELECT started_at FROM agent_runs WHERE id = conversations.active_run_id))",
            whereArgs: [
              conversation.id,
              header['active_run_id'],
              header['active_run_id'],
            ],
          );
        }
        for (final row in messageRows) {
          if (terminalIds.contains(row['id'])) continue;
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
        for (final message in changed) {
          if (message.quickReplyToId == null ||
              terminalIds.contains(message.id))
            continue;
          batch.insert('message_quick_replies', {
            'message_id': message.id,
            'parent_message_id': message.quickReplyToId,
            'actor_id': message.senderId,
            'reply_key': message.quickReplyKey,
          });
        }
        for (final entry in recipients.entries) {
          if (terminalIds.contains(entry.key)) continue;
          for (final senderId in entry.value) {
            batch.insert('message_recipients', {
              'message_id': entry.key,
              'sender_id': senderId,
            });
          }
        }
        if (saveDraft)
          batch.delete(
            'attachments',
            where: 'conversation_id = ? AND message_id IS NULL',
            whereArgs: [conversation.id],
          );
        for (final row in imageRows) {
          if (terminalIds.contains(row['message_id'])) continue;
          upsert(batch, 'attachments', row);
        }
        if (makeActive) {
          batch.insert('app_state', {
            'key': 'active_conversation',
            'value': conversation.id,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
        if (participation != null) {
          await GroupParticipation.setIn(
            txn,
            conversation.id,
            participation.senderId,
            participation.paused,
          );
        }
        if (messageRows.isNotEmpty) {
          await txn.rawUpdate(
            "UPDATE conversations SET message_count = (SELECT COUNT(*) FROM messages WHERE conversation_id = ?), preview = (SELECT text FROM messages WHERE conversation_id = ? AND kind NOT IN ('commentary', 'reasoning', 'quick_reply') ORDER BY created_at DESC, id DESC LIMIT 1), updated_at = MAX(updated_at, COALESCE((SELECT MAX(created_at) FROM messages WHERE conversation_id = ?), created_at)) WHERE id = ?",
            [
              conversation.id,
              conversation.id,
              conversation.id,
              conversation.id,
            ],
          );
        }
      });
      conversation.isStored = true;
      remember(changed);
    });
    // A failed write must not block later attempts; its caller still receives the error.
    _saving = write.catchError((Object error) {});
    return write;
  }

  Future<void> updateMetadata(
    Conversation conversation,
    Map<String, Object?> values,
  ) {
    final initial = conversationRow(conversation);
    return mutate(
      () => database.transaction((txn) async {
        await txn.insert(
          'conversations',
          initial,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await txn.update(
          'conversations',
          values,
          where: 'id = ?',
          whereArgs: [conversation.id],
        );
      }),
    );
  }

  Future<void> markRunRead(
    String conversationId,
    String runId,
  ) => mutate(() async {
    await database.rawInsert(
      "INSERT INTO app_state(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value WHERE (SELECT started_at FROM agent_runs WHERE id = excluded.value) >= (SELECT started_at FROM agent_runs WHERE id = app_state.value)",
      ['seen_run:$conversationId', runId],
    );
  });

  Future<void> saveContextSummary(
    String conversationId,
    ContextSummary summary,
  ) => mutate(() async {
    await database.rawInsert(
      "INSERT INTO app_state(key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value WHERE (SELECT created_at FROM messages WHERE id = json_extract(excluded.value, '\$.throughMessageId')) >= (SELECT created_at FROM messages WHERE id = json_extract(app_state.value, '\$.throughMessageId'))",
      ['context_summary:$conversationId', jsonEncode(summary.toJson())],
    );
  });

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
