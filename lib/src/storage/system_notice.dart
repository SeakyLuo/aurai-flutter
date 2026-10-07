import 'package:sqflite/sqflite.dart';

import '../domain/agent_models.dart';
import '../domain/message_sender.dart';
import 'conversation_rows.dart';

Future<AgentMessage> writeSystemNotice(
  DatabaseExecutor db,
  String conversationId,
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
  await db.insert('messages', messageRow(conversationId, notice));
  await db.rawUpdate(
    'UPDATE conversations SET message_count = message_count + 1, preview = ?, updated_at = ? WHERE id = ?',
    [text, notice.createdAt.microsecondsSinceEpoch, conversationId],
  );
  return notice;
}
