import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/agent_models.dart';
import '../domain/message_sender.dart';
import 'conversation_rows.dart';

Future<AgentMessage?> writeGroupMemberNotice(
  DatabaseExecutor db,
  String groupId,
  List<String> added,
  List<String> removed,
) async {
  final ids = {...added, ...removed};
  if (ids.isEmpty) return null;
  final rows = await db.query(
    'message_senders',
    columns: ['id', 'name'],
    where: 'id IN (${List.filled(ids.length, '?').join(',')})',
    whereArgs: ids.toList(),
  );
  final names = {for (final row in rows) row['id']: row['name']};
  return writeGroupNotice(
    db,
    groupId,
    [
      if (added.isNotEmpty) '${added.map((id) => names[id]).join('、')} 加入群聊',
      if (removed.isNotEmpty)
        '${removed.map((id) => names[id]).join('、')} 离开群聊',
    ].join('；'),
  );
}

Future<AgentMessage> writeGroupNotice(
  DatabaseExecutor db,
  String groupId,
  String text, {
  String? id,
}) async {
  final notice = AgentMessage(
    id: id ?? newMessageId(),
    role: AgentMessageRole.user,
    senderId: MessageSender.localUser.id,
    isSystem: true,
    text: text,
    createdAt: DateTime.now(),
  );
  await db.insert('messages', messageRow(groupId, notice));
  await db.rawUpdate(
    'UPDATE conversations SET message_count = message_count + 1, preview = ?, updated_at = ? WHERE id = ?',
    [text, notice.createdAt.microsecondsSinceEpoch, groupId],
  );
  return notice;
}

Future<void> refreshGroupNoticeName(
  DatabaseExecutor db,
  String senderId,
  String oldName,
  String newName,
) async {
  if (oldName == newName) return;
  final encodedOld = jsonEncode(oldName);
  final encodedNew = jsonEncode(newName);
  final groupMembership =
      'SELECT conversation_id FROM conversation_members WHERE sender_id = ?';
  await db.rawUpdate(
    '''UPDATE conversations SET preview = replace(preview, ?, ?)
       WHERE kind = 'group' AND id IN ($groupMembership)
       AND EXISTS (SELECT 1 FROM messages
                   WHERE conversation_id = conversations.id
                   AND kind = 'system' AND text = conversations.preview)''',
    [oldName, newName, senderId],
  );
  await db.rawUpdate(
    '''UPDATE messages SET text = replace(text, ?, ?),
       interactive_json = replace(interactive_json, ?, ?)
       WHERE kind = 'system' AND conversation_id IN ($groupMembership)
       AND instr(text, ?) > 0''',
    [
      oldName,
      newName,
      encodedOld.substring(1, encodedOld.length - 1),
      encodedNew.substring(1, encodedNew.length - 1),
      senderId,
      oldName,
    ],
  );
}
