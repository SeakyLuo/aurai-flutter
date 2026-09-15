import 'group_unread_messages.dart';
import 'conversation_visibility.dart';
import 'group_list_preview.dart';
import '../domain/message_sender.dart';
import '../features/chat/conversation.dart';
import 'conversation_rows.dart';
import 'group_chat_store.dart';

class HomeConversations {
  HomeConversations(this.store);
  final GroupChatStore store;
  static const pageSize = 50;

  Future<List<Conversation>> recent({int offset = 0}) async {
    final rows = await store.database.query(
      'conversations',
      where: 'archived = 0 AND $visibleConversation AND $localUserConversation',
      orderBy: 'pinned DESC, updated_at DESC, id DESC',
      limit: pageSize,
      offset: offset,
    );
    return _headers(rows);
  }

  Future<List<Conversation>> forAi(String senderId, {int offset = 0}) async {
    final rows = await store.database.query(
      'conversations',
      where:
          "kind = 'direct' AND default_sender_id = ? AND archived = 0 AND $visibleConversation AND $localUserConversation",
      whereArgs: [senderId],
      orderBy: 'pinned DESC, updated_at DESC, id DESC',
      limit: pageSize,
      offset: offset,
    );
    return _headers(rows);
  }

  Future<List<Conversation>> _headers(List<Map<String, Object?>> rows) async {
    final items = rows.map(conversationFromRow).toList();
    if (items.isEmpty) return items;
    final results = await Future.wait<Object?>([
      store.database.query(
        'app_state',
        where: 'key IN (${List.filled(items.length, '?').join(',')})',
        whereArgs: items.map((c) => 'seen_run:${c.id}').toList(),
        limit: pageSize,
      ),
      loadConversationListPreviews(store.database, items),
      store.database.query(
        'attachments',
        columns: ['conversation_id', 'kind', 'display_name'],
        where:
            'message_id IS NULL AND conversation_id IN (${List.filled(items.length, '?').join(',')})',
        whereArgs: items.map((c) => c.id).toList(),
        orderBy: 'position',
      ),
      GroupUnreadMessages(store.database).load(items),
    ]);
    final attachments = <String, Set<String>>{};
    for (final row in results[2] as List<Map<String, Object?>>) {
      attachments
          .putIfAbsent(row['conversation_id'] as String, () => {})
          .add(row['kind'] == 'image' ? '[图片]' : '[文件] ${row['display_name']}');
    }
    for (final item in items) {
      item.storedDraftAttachmentPreview = attachments[item.id]?.join(' ');
    }
    final seen = results[0] as List<Map<String, Object?>>;
    final values = {for (final row in seen) row['key']: row['value'] as String};
    for (final item in items) {
      item.seenRunId = values['seen_run:${item.id}'];
    }
    return items;
  }

  Future<Map<String, MessageSender>> senders(List<Conversation> items) async {
    final ids = items
        .where((c) => c.kind == ConversationKind.direct)
        .map((c) => c.defaultSenderId)
        .toSet()
        .toList();
    if (ids.isEmpty) return {};
    final rows = await store.database.query(
      'message_senders',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
      limit: pageSize,
    );
    return {
      for (final row in rows) row['id'] as String: MessageSender.fromRow(row),
    };
  }
}
