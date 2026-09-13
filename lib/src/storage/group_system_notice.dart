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
