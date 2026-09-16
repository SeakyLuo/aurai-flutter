import 'dart:async';
import 'message_callbacks.dart';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../domain/interactive_message.dart';
import '../domain/agent_models.dart';
import '../domain/message_sender.dart';
import 'conversation_rows.dart';

class InteractiveMessageStore {
  InteractiveMessageStore(this.database);
  final Database database;
  static final changes = StreamController<String>.broadcast();

  Future<({InteractiveMessage card, AgentMessage? notice, String? url})> click(
    String conversationId,
    String messageId,
    String buttonId,
    int revision, {
    required MessageSender actor,
    required int participantRevision,
  }) => database.transaction((txn) async {
    final rows = await txn.query(
      'messages',
      columns: ['kind', 'interactive_json', 'sender_id'],
      where: 'id = ? AND conversation_id = ?',
      whereArgs: [messageId, conversationId],
    );
    if (rows.isEmpty ||
        rows.single['kind'] == 'system' ||
        rows.single['interactive_json'] == null)
      throw StateError('消息已撤回或删除');
    final card = InteractiveMessage.fromJson(
      jsonDecode(rows.single['interactive_json'] as String)
          as Map<String, dynamic>,
    );
    if (card.revision != revision ||
        card.participantRevision(actor.id) != participantRevision)
      throw InteractiveMessageChanged(card);
    if (card.closed) throw StateError('这条交互消息已结束');
    final view = card.viewFor(actor.id);
    final button = view.buttons.firstWhere((b) => b['id'] == buttonId);
    if (button['disabled'] == true) throw StateError('这个选项已处理');
    final action = button['action'] as String;
    final target = action == 'update' && button['nextState'] != null
        ? card.states.firstWhere((state) => state['id'] == button['nextState'])
        : null;
    final nextButtons = target != null
        ? (target['buttons'] as List)
              .map((b) => Map<String, Object?>.from(b as Map))
              .toList()
        : [
            for (final b in view.buttons)
              if (b['id'] == buttonId &&
                  b['repeatable'] == false &&
                  !card.singleChoice)
                {
                  ...b,
                  'disabled': true,
                  'label': b['completedLabel'] ?? '${b['label']} ✓',
                }
              else
                b,
          ];
    final previous = card.participants[actor.id];
    final snapshotCount = previous == null
        ? 0
        : previous['snapshotCount'] as int? ??
              Sqflite.firstIntValue(
                await txn.rawQuery(
                  'SELECT COUNT(*) FROM interactive_actions WHERE message_id = ? AND actor_id = ? AND before_json IS NOT NULL',
                  [messageId, actor.id],
                ),
              )!;
    final now = DateTime.now().microsecondsSinceEpoch;
    final state = <String, Object?>{
      'name': actor.name,
      'revision': participantRevision + 1,
      'snapshotCount': snapshotCount + 1,
      'definitionRevision': revision,
      'title': target?['title'] ?? view.title,
      'body':
          target?['body'] ??
          (action == 'update' ? button['nextBody'] : view.body),
      'buttons': nextButtons,
      'buttonId': buttonId,
      'label': button['label'],
      'updatedAt': now,
    };
    final next = InteractiveMessage(
      revision: card.revision,
      title: card.title,
      body: card.body,
      buttons: card.buttons,
      states: card.states,
      participation: card.participation,
      participants: {...card.participants, actor.id: state},
    );
    await txn.insert('interactive_actions', {
      'message_id': messageId,
      'actor_id': actor.id,
      'actor_name': actor.name,
      'button_id': buttonId,
      'label': button['label'],
      'definition_revision': revision,
      'participant_revision': participantRevision + 1,
      'before_json': jsonEncode({
        'revision': view.revision,
        'title': view.title,
        'body': view.body,
        'buttons': view.buttons,
        'participation': view.participation,
        if (card.participants[actor.id] case final previous?)
          'selectedLabel': previous['label'],
      }),
      'created_at': now,
    });
    await txn.update(
      'messages',
      {'interactive_json': jsonEncode(next.toJson(includeParticipants: true))},
      where: 'id = ?',
      whereArgs: [messageId],
    );
    if (button['notifyAi'] == true) {
      await MessageCallbacks.enqueue(
        txn,
        id: newMessageId(),
        messageId: messageId,
        conversationId: conversationId,
        senderId: rows.single['sender_id'] as String,
        payload: {
          'source': 'button',
          if (card.visible('visibility') ||
              rows.single['sender_id'] == actor.id) ...{
            'actorId': actor.id,
            'actorName': actor.name,
            'buttonId': buttonId,
            'label': button['label'],
          } else
            'participationRecorded': true,
          'revision': revision,
        },
      );
    }
    final notice = await writeNotice(
      txn,
      conversationId,
      '${actor.name}参与了“${card.title}”',
    );
    return (
      card: next,
      notice: notice,
      url: action == 'openUrl' ? button['url'] as String : null,
    );
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
