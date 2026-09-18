import 'package:collection/collection.dart';
import 'dart:async';
import '../domain/interactive_selection.dart';
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
    Object? inputValue,
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
    card.validateTransport(html: rows.single['kind'] == 'html_game');
    if (card.revision != revision ||
        card.participantRevision(actor.id) != participantRevision)
      throw InteractiveMessageChanged(card);
    final pending = card.participants[actor.id]?['callback'] as Map?;
    if (['queued', 'processing'].contains(pending?['status']) &&
        (pending?['buttonId'] ?? card.participants[actor.id]?['buttonId']) ==
            buttonId)
      throw StateError('AI 正在处理这次操作，请等待结果');
    if (card.closed) throw StateError('这条交互消息已结束');
    final view = card.viewFor(actor.id);
    var button = view.buttons.firstWhere((b) => b['id'] == buttonId);
    if (button['disabled'] == true) throw StateError('这个选项已处理');
    final action = button['action'] as String;
    if (action == 'openUrl' &&
        button['notifyAi'] != true &&
        button['repeatable'] != false)
      return (card: card, notice: null, url: button['url'] as String);
    if (button['selection'] case final Map config) {
      button = InteractiveSelection(
        Map<String, Object?>.from(config),
      ).resolve(button, inputValue);
    } else if (inputValue != null) {
      if (rows.single['kind'] != 'html_game' ||
          action != 'submit' ||
          !['text', 'json'].contains(button['input']))
        throw ArgumentError('这个按钮不接受页面输入');
      if (button['input'] == 'text' &&
          (inputValue is! String || inputValue.trim().isEmpty))
        throw ArgumentError('请填写文本内容');
      if (utf8.encode(jsonEncode(inputValue)).length > 16384)
        throw ArgumentError('提交数据不能超过 16 KB');
    } else if (button['input'] != null) {
      throw ArgumentError('请提供页面输入数据');
    }
    final nextSession = card.shared
        ? switch (action) {
            'submit' => card.engine.submit(actor.id, actor.name, {
              ...button,
              if (inputValue != null && button['selection'] == null)
                'value': inputValue,
            }),
            'nextRound' => card.engine.nextRound(actor.id),
            _ => card.engine,
          }
        : null;
    final newRound =
        nextSession != null && nextSession.round != card.engine.round;
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
                  !card.singleChoice &&
                  !card.shared)
                {
                  ...b,
                  'disabled': true,
                  'label': b['completedLabel'] ?? b['label'],
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
    final callbackId = button['notifyAi'] == true ? newMessageId() : null;
    final state = <String, Object?>{
      if (callbackId != null)
        'callback': {
          'id': callbackId,
          'buttonId': buttonId,
          'status': 'queued',
          'updatedAt': now,
        },
      'name': actor.name,
      'revision': participantRevision + 1,
      'snapshotCount': snapshotCount,
      'definitionRevision': revision,
      'showStatistics': target?['showStatistics'] ?? view.showStatistics,
      'buttonColumns': newRound
          ? card.buttonColumns
          : target?['buttonColumns'] ?? view.buttonColumns,
      'title': newRound ? card.title : target?['title'] ?? view.title,
      'body': newRound
          ? card.body
          : target?['body'] ??
                (action == 'update' ? button['nextBody'] : view.body),
      'buttons': newRound ? card.buttons : nextButtons,
      'buttonId': buttonId,
      'label': button['label'],
      if (button['selections'] != null) ...{
        'selections': button['selections'],
        'value': button['value'],
      },
      'updatedAt': now,
    };
    final next = InteractiveMessage(
      revision:
          nextSession != null &&
              (nextSession.round != card.engine.round ||
                  nextSession.phase != card.engine.phase)
          ? card.revision + 1
          : card.revision,
      showStatistics: card.showStatistics,
      buttonColumns: card.buttonColumns,
      interaction: card.interaction,
      session: nextSession?.runtime ?? card.session,
      title: card.title,
      body: card.body,
      buttons: card.buttons,
      states: card.states,
      participation: card.participation,
      participants: {
        for (final entry in card.participants.entries)
          entry.key: newRound
              ? (Map<String, Object?>.from(entry.value)
                  ..remove('title')
                  ..remove('body')
                  ..remove('buttons')
                  ..remove('buttonColumns')
                  ..remove('callback'))
              : entry.value,
        actor.id: state,
      },
    );
    final nextView = next.viewFor(actor.id);
    final pageChanged = newRound ||
        (nextSession != null && nextSession.phase != card.engine.phase) ||
        view.title != nextView.title ||
        view.body != nextView.body ||
        view.buttonColumns != nextView.buttonColumns ||
        view.showStatistics != nextView.showStatistics ||
        !const DeepCollectionEquality().equals(
          [for (final b in view.buttons) {...b}..remove('disabled')],
          [for (final b in nextView.buttons)
            {...b,
              if (b['disabled'] == true && b['completedLabel'] == b['label'])
                'label': view.buttons.firstWhere((old) => old['id'] == b['id'])['label'],
            }..remove('disabled')],
        );
    state['snapshotCount'] = snapshotCount + (pageChanged ? 1 : 0);
    await txn.insert('interactive_actions', {
      'message_id': messageId,
      'actor_id': actor.id,
      'actor_name': actor.name,
      'button_id': buttonId,
      'label': button['label'],
      'definition_revision': revision,
      'participant_revision': participantRevision + 1,
      'before_json': pageChanged ? jsonEncode({
        'revision': view.revision,
        'showStatistics': view.showStatistics,
        'buttonColumns': view.buttonColumns,
        'title': view.title,
        'body': view.body,
        'buttons': view.buttons,
        'participation': view.participation,
        if (card.participants[actor.id]?['callback'] != null)
          'callback': card.participants[actor.id]!['callback'],
        if (card.hasInteraction)
          'interactionView': card.interactionView(actor.id),
        if (card.choices[actor.id] case final previous?)
          'selectedLabel': previous['label'],
      }) : null,
      'created_at': now,
    });
    if (pending != null) {
      await txn.update(
        'message_callbacks',
        {'status': 'expired', 'processed_at': now},
        where: 'id = ? AND processed_at IS NULL',
        whereArgs: [pending['id']],
      );
    }
    if (newRound) {
      await txn.update(
        'message_callbacks',
        {'status': 'expired', 'processed_at': now},
        where:
            'message_id = ? AND actor_id IS NOT NULL AND processed_at IS NULL',
        whereArgs: [messageId],
      );
    }
    final encoded = jsonEncode(next.toJson(includeParticipants: true));
    await txn.update(
      'messages',
      {'interactive_json': encoded},
      where: 'id = ?',
      whereArgs: [messageId],
    );
    if (callbackId != null) {
      await MessageCallbacks.enqueue(
        txn,
        id: callbackId,
        actorId: actor.id,
        participantRevision: participantRevision + 1,
        messageId: messageId,
        conversationId: conversationId,
        senderId: rows.single['sender_id'] as String,
        payload: {
          'source': 'button',
          if (card.visible(
                'visibility',
                actor: rows.single['sender_id'] as String,
              ) ||
              rows.single['sender_id'] == actor.id) ...{
            'actorId': actor.id,
            'actorName': actor.name,
            'buttonId': buttonId,
            'label': button['label'],
            if (button['selections'] != null) ...{
              'selections': button['selections'],
              'value': button['value'],
            },
          } else
            'participationRecorded': true,
          'revision': revision,
        },
      );
    }
    final conversations = await txn.query(
      'conversations',
      columns: ['kind', 'archived', 'default_sender_id'],
      where: 'id = ?',
      whereArgs: [conversationId],
      limit: 1,
    );
    final conversation = conversations.single;
    final direct = conversation['kind'] == 'direct';
    final notice = await writeNotice(
      txn,
      conversationId,
      !card.visible('visibility', actor: actor.id) ||
              card.participation['visibilityActors'] != null
          ? '${actor.name}提交了“${card.title}”'
          : '${actor.name}在“${card.title}”中选择了“${button['label']}”',
      audience: (card.participation['audience'] as List?)?.cast<String>(),
    );
    if (callbackId == null && actor.id == MessageSender.localUser.id) {
      if (direct && conversation['archived'] == 0) {
        final recipient = conversation['default_sender_id'] as String;
        if (next.canView(recipient)) {
          await MessageCallbacks.enqueue(
            txn,
            id: newMessageId(),
            messageId: messageId,
            conversationId: conversationId,
            senderId: recipient,
            payload: {
              'source': 'interactionNotice',
              'title': next.title,
              if (next.visible('visibility', actor: recipient)) ...{
                'actorName': actor.name,
                'label': button['label'],
              } else
                'participationRecorded': true,
            },
          );
        }
      }
    }
    return (
      card: next,
      notice: notice,
      url: action == 'openUrl' ? button['url'] as String : null,
    );
  });

  static Future<AgentMessage> writeNotice(
    DatabaseExecutor db,
    String conversationId,
    String text, {
    List<String>? audience,
  }) async {
    final notice = AgentMessage(
      id: newMessageId(),
      role: AgentMessageRole.user,
      senderId: MessageSender.localUser.id,
      text: text,
      isSystem: true,
      interactive: audience == null
          ? null
          : InteractiveMessage(
              revision: 0,
              title: text,
              body: '',
              buttons: const [],
              participation: {'audience': audience},
            ),
      createdAt: DateTime.now(),
    );
    await db.insert('messages', messageRow(conversationId, notice));
    await db.rawUpdate(
      'UPDATE conversations SET message_count = message_count + 1, preview = ?, updated_at = ? WHERE id = ?',
      [
        notice.interactive?.canView(MessageSender.localUser.id) == false
            ? '私密交互消息'
            : text,
        notice.createdAt.microsecondsSinceEpoch,
        conversationId,
      ],
    );
    return notice;
  }
}
