import 'package:sqflite/sqflite.dart';

import '../features/chat/conversation.dart';
import '../domain/message_sender.dart';

/// Resolve the latest visible message for the current page, not cached names.
Future<void> loadGroupListPreviews(
  Database database,
  List<Conversation> conversations,
) async {
  final groups = {
    for (final conversation in conversations)
      if (conversation.kind == ConversationKind.group)
        conversation.id: conversation,
  };
  if (groups.isEmpty) return;
  final rows = await database.rawQuery(
    '''SELECT id, conversation_id, sender_id, kind, substr(text, 1, 160) AS text
       FROM messages WHERE id IN (
         SELECT (SELECT id FROM messages
           WHERE conversation_id = conversations.id AND kind != 'commentary'
           ORDER BY created_at DESC, id DESC LIMIT 1)
         FROM conversations WHERE id IN (${_slots(groups.length)})
       )''',
    groups.keys.toList(),
  );
  final senderIds = {
    for (final row in rows) row['sender_id'] as String,
    for (final group in groups.values) ...group.creationMemberIds,
  };
  if (senderIds.isEmpty) return;
  final results = await Future.wait([
    database.query(
      'message_senders',
      where: 'id IN (${_slots(senderIds.length)})',
      whereArgs: senderIds.toList(),
    ),
    rows.isEmpty
        ? Future.value(<Map<String, Object?>>[])
        : database.query(
            'attachments',
            columns: ['message_id', 'kind', 'mime_type', 'display_name'],
            where:
                'conversation_id IN (${_slots(groups.length)}) AND message_id IN (${_slots(rows.length)})',
            whereArgs: [...groups.keys, ...rows.map((row) => row['id'])],
            orderBy: 'position',
          ),
  ]);
  final senders = {
    for (final row in results[0]) row['id']: MessageSender.fromRow(row),
  };
  final groupsWithMessages = rows.map((r) => r['conversation_id']).toSet();
  for (final group in groups.values) {
    group.creationMembers = [
      for (final id in group.creationMemberIds) senders[id]!,
    ];
    if (!groupsWithMessages.contains(group.id)) {
      group.storedPreview = group.creationMessage;
      group.storedPreviewIsSystem = group.creationMemberIds.isNotEmpty;
    }
  }
  final names = {
    for (final row in results[0]) row['id']: row['name'] as String,
  };
  final attachments = <Object?, List<Map<String, Object?>>>{};
  for (final row in results[1]) {
    attachments.putIfAbsent(row['message_id'], () => []).add(row);
  }
  for (final row in rows) {
    final text = row['id'] == 'group-created:${row['conversation_id']}'
        ? groups[row['conversation_id']]!.creationMessage!
        : row['text'] as String;
    final labels = <String>{};
    for (final attachment in attachments[row['id']] ?? const []) {
      final mime = attachment['mime_type'] as String;
      labels.add(
        attachment['kind'] == 'image' || mime.startsWith('image/')
            ? '[图片]'
            : mime.startsWith('video/')
            ? '[视频]'
            : mime.startsWith('audio/')
            ? '[音频]'
            : '[文件] ${attachment['display_name']}',
      );
    }
    final body = [...labels, if (text.isNotEmpty) text].join(' ');
    groups[row['conversation_id']]!.storedPreviewIsSystem =
        row['kind'] == 'system';
    groups[row['conversation_id']]!.storedPreview = row['kind'] == 'system'
        ? body
        : '${names[row['sender_id']]}：$body';
  }
}

String _slots(int count) => List.filled(count, '?').join(',');
