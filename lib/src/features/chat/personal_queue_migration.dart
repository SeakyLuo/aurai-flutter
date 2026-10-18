part of 'chat_controller.dart';

extension PersonalQueueMigration on ChatController {
  Future<void> _movePersonalQueuesToHistory() async {
    await _store.database.transaction((txn) async {
      final rows = await txn.query(
        'app_state',
        where:
            "key GLOB 'pending_message_queue:*' AND substr(key, 23) IN "
            "(SELECT id FROM conversations WHERE personal_chat = 1)",
      );
      final batch = txn.batch();
      for (final row in rows) {
        final key = row['key'] as String;
        final id = key.substring(22);
        final queue = PendingMessageQueue.restore(
          row['value'] as String,
          _imageStore.directory,
        );
        for (final message in queue.messages) {
          batch.insert('messages', messageRow(id, message));
          for (var i = 0; i < message.images.length; i++) {
            batch.insert(
              'attachments',
              attachmentRow(id, message.images[i], i, messageId: message.id),
            );
          }
          for (var i = 0; i < message.files.length; i++) {
            batch.insert(
              'attachments',
              fileAttachmentRow(id, message.files[i], i, messageId: message.id),
            );
          }
        }
        if (queue.messages.isNotEmpty) {
          // Preserve original message IDs, timestamps and attachment references.
          // Expose Continue Reply instead of silently discarding a paused queue.
          batch.rawUpdate(
            "UPDATE conversations SET message_count = message_count + ?, "
            "pending_goal = COALESCE(pending_goal, ?), "
            "run_state = CASE WHEN run_state = 'idle' THEN 'interrupted' "
            "ELSE run_state END WHERE id = ?",
            [queue.messages.length, queue.messages.last.text, id],
          );
        }
        batch.delete('app_state', where: 'key = ?', whereArgs: [key]);
      }
      if (rows.isNotEmpty) {
        batch.rawUpdate(
          "UPDATE conversations SET preview = (SELECT text FROM messages "
          "WHERE conversation_id = conversations.id AND kind NOT IN "
          "('commentary', 'reasoning', 'quick_reply') ORDER BY created_at DESC, id DESC LIMIT 1), "
          "updated_at = MAX(updated_at, COALESCE((SELECT MAX(created_at) FROM messages "
          "WHERE conversation_id = conversations.id), created_at)) "
          "WHERE id IN (SELECT value FROM json_each(?))",
          [
            jsonEncode(
              rows.map((row) => (row['key'] as String).substring(22)).toList(),
            ),
          ],
        );
      }
      await batch.commit(noResult: true);
    });
  }
}
