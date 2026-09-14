import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/interactive_message.dart';
import '../domain/agent_models.dart';
import '../domain/message_sender.dart';
import 'conversation_rows.dart';

class InteractiveMessageStore {
  InteractiveMessageStore(this.database);
  final Database database;

  Future<({InteractiveMessage card, AgentMessage? notice, String? url})> click(
    String conversationId,
    String messageId,
    String buttonId,
    int revision,
  ) => database.transaction((txn) async {
    final rows = await txn.query(
      'messages',
      columns: ['kind', 'interactive_json'],
      where: 'id = ? AND conversation_id = ?',
      whereArgs: [messageId, conversationId],
    );
    if (rows.isEmpty || rows.single['kind'] == 'system')
      throw StateError('消息已撤回或删除');
    final card = InteractiveMessage.fromJson(
      jsonDecode(rows.single['interactive_json'] as String)
          as Map<String, dynamic>,
    );
    if (card.revision != revision) throw StateError('卡片已更新，请查看最新状态后重试');
    final button = card.buttons.firstWhere((b) => b['id'] == buttonId);
    if (button['disabled'] == true) throw StateError('这个选项已处理');
    final action = button['action'] as String;
    if (action == 'openUrl')
      return (card: card, notice: null, url: button['url'] as String);
    final body = action == 'update' ? button['nextBody'] as String : card.body;
    final next = InteractiveMessage(
      revision: revision + 1,
      title: card.title,
      body: body,
      buttons: [
        for (final b in card.buttons)
          if (b['id'] == buttonId && b['repeatable'] == false)
            {
              ...b,
              'disabled': true,
              'label': b['completedLabel'] ?? '${b['label']} ✓',
            }
          else
            b,
      ],
    );
    final changed =
        jsonEncode(card.toJson()..remove('revision')) !=
        jsonEncode(next.toJson()..remove('revision'));
    if (!changed && action != 'acknowledge')
      return (card: card, notice: null, url: null);
    await txn.update(
      'messages',
      {
        'interactive_json': jsonEncode(next.toJson()),
        'text': '${next.title}\n${next.body}',
      },
      where: 'id = ?',
      whereArgs: [messageId],
    );
    final notice = await writeNotice(
      txn,
      conversationId,
      '你在“${card.title}”中选择了“${button['label']}”',
    );
    return (card: next, notice: notice, url: null);
  });

  static Future<AgentMessage> writeNotice(
    DatabaseExecutor db,
    String conversationId,
    String text,
  ) async {
    final notice = AgentMessage(
      id: newMessageId(),
      role: AgentMessageRole.user,
      senderId: MessageSender.localUser.id,
      text: text,
      isSystem: true,
      createdAt: DateTime.now(),
    );
    await db.insert('messages', messageRow(conversationId, notice));
    await db.rawUpdate(
      'UPDATE conversations SET message_count = message_count + 1, preview = ?, updated_at = ? WHERE id = ?',
      [text, notice.createdAt.microsecondsSinceEpoch, conversationId],
    );
    return notice;
  }
}
