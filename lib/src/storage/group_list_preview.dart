import '../domain/message_summary.dart';
import 'package:sqflite/sqflite.dart';

import '../features/chat/conversation.dart';
import '../domain/message_sender.dart';

/// Resolve the latest visible message for the current page, not cached names.
Future<void> loadConversationListPreviews(
  Database database,
  List<Conversation> conversations,
) async {
  final groups = {
    for (final conversation in conversations) conversation.id: conversation,
  };
  if (groups.isEmpty) return;
  final rows = await database.rawQuery(
    '''SELECT id, conversation_id, sender_id, kind, text, json_extract(interactive_json, '\$.title') AS interactive_title, json_extract(interactive_json, '\$.body') AS interactive_body, created_at
       FROM messages WHERE id IN (
         SELECT (SELECT id FROM messages
           WHERE conversation_id = conversations.id AND kind != 'commentary'
             AND NOT (kind = 'system' AND text = '私密交互消息已更新')
             AND (interactive_json IS NULL
               OR json_extract(interactive_json, '\$.participation.audience') IS NULL
               OR EXISTS (SELECT 1 FROM json_each(interactive_json, '\$.participation.audience') WHERE value = 'user:local'))
           ORDER BY created_at DESC, id DESC LIMIT 1)
         FROM conversations WHERE id IN (${_slots(groups.length)})
       )''',
    groups.keys.toList(),
  );
  final senderIds = {
    MessageSender.localUser.id,
    for (final row in rows) row['sender_id'] as String,
    for (final group in groups.values) ...group.creationMemberIds,
  };
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
  for (final group in groups.values.where(
    (c) => c.kind == ConversationKind.group,
  )) {
    group.creationUserName = senders[MessageSender.localUser.id]!.name;
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
    groups[row['conversation_id']]!.lastMessageAt =
        DateTime.fromMicrosecondsSinceEpoch(row['created_at'] as int);
    final text = row['id'] == 'group-created:${row['conversation_id']}'
        ? groups[row['conversation_id']]!.creationMessage!
        : row['interactive_title'] != null
        ? '${row['interactive_title']}\n${row['interactive_body']}'
        : row['text'] as String;
    final body = MessageSummary.content(
      text: text,
      htmlTitle: row['kind'] == 'html_game' ? text : null,
      interactiveTitle: row['interactive_title'] as String?,
      attachments: [
        for (final attachment in attachments[row['id']] ?? const [])
          MessageSummary.attachment(
            kind: attachment['kind'] as String,
            mimeType: attachment['mime_type'] as String,
            name: attachment['display_name'] as String?,
          ),
      ],
    );
    groups[row['conversation_id']]!.storedPreviewIsSystem =
        row['kind'] == 'system';
    groups[row['conversation_id']]!.storedPreview = MessageSummary.sender(
      body,
      senderId: row['sender_id'] as String,
      senderName: names[row['sender_id']]!,
      isSystem: row['kind'] == 'system',
    );
  }
}

String _slots(int count) => List.filled(count, '?').join(',');
