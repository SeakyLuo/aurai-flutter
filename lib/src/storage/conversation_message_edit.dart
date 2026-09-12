import '../domain/agent_models.dart';
import '../features/chat/conversation.dart';
import 'conversation_rows.dart';
import 'conversation_store.dart';

extension ConversationMessageEdit on ConversationStore {
  Future<List<String>> replaceFromMessage(
    Conversation replacement,
    AgentMessage original,
  ) async {
    await writer.flush();
    final time = original.createdAt.microsecondsSinceEpoch;
    const after =
        'conversation_id = ? AND (created_at > ? OR (created_at = ? AND id > ?))';
    final afterArgs = [replacement.id, time, time, original.id];
    final removedImages = await database.transaction((txn) async {
      final images = await txn.query(
        'attachments',
        columns: ['file_name'],
        where:
            'message_id = ? OR message_id IN (SELECT id FROM messages WHERE $after)',
        whereArgs: [original.id, ...afterArgs],
      );

      await txn.delete(
        'agent_runs',
        where:
            'conversation_id = ? AND (user_message_id = ? OR user_message_id IN '
            '(SELECT id FROM messages WHERE $after))',
        whereArgs: [replacement.id, original.id, ...afterArgs],
      );
      await txn.delete('messages', where: after, whereArgs: afterArgs);
      await txn.update(
        'messages',
        {'text': replacement.messages.last.text},
        where: 'id = ? AND conversation_id = ?',
        whereArgs: [original.id, replacement.id],
      );
      await txn.delete(
        'attachments',
        where: 'message_id = ?',
        whereArgs: [original.id],
      );
      final editedImages = replacement.messages.last.images;
      final batch = txn.batch();
      for (var i = 0; i < editedImages.length; i++) {
        batch.insert(
          'attachments',
          attachmentRow(
            replacement.id,
            editedImages[i],
            i,
            messageId: original.id,
          ),
        );
      }
      await batch.commit(noResult: true);
      final count = await txn.rawQuery(
        'SELECT COUNT(*) AS count FROM messages WHERE conversation_id = ?',
        [replacement.id],
      );
      replacement.messageCount = count.single['count']! as int;
      if (replacement.messageCount == 1 && replacement.title == original.text) {
        replacement.storedTitle = replacement.messages.last.text.isEmpty
            ? '图片对话'
            : replacement.messages.last.text;
      }
      await txn.update(
        'conversations',
        conversationRow(replacement),
        where: 'id = ?',
        whereArgs: [replacement.id],
      );
      await txn.delete(
        'app_state',
        where: 'key IN (?, ?)',
        whereArgs: [
          'context_summary:${replacement.id}',
          'seen_run:${replacement.id}',
        ],
      );
      final retained = editedImages.map((image) => image.path).toSet();
      return images
          .map((row) => '${reader.imageDirectory}/${row['file_name']}')
          .where((path) => !retained.contains(path))
          .toList();
    });
    writer.retain(replacement.messages);
    return removedImages;
  }
}
