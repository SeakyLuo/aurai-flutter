import 'package:sqflite/sqflite.dart';
import '../domain/agent_models.dart';
import '../domain/interactive_message.dart';
import '../domain/message_sender.dart';
import '../storage/conversation_rows.dart';

/// Creates messages and native cards using the authenticated event identity.
class MiniappMessageCapability {
  const MiniappMessageCapability();

  Future<List<({AgentMessage message, bool wakeAi})>> emit(
    DatabaseExecutor txn, {
    required String conversationId,
    required String messageId,
    required String actorId,
    String? continuationSenderId,
    required Set<String> memberIds,
    required Set<String> agents,
    required Map<String, MessageSender> senders,
    required Map<String, Object?> bindings,
    required List effects,
  }) async {
    if (effects.length > 64) throw ArgumentError('单次事件最多产生 64 条消息');
    final created = <({AgentMessage message, bool wakeAi})>[];
    final batch = txn.batch();
    for (final raw in effects) {
      final effect = (raw as Map).cast<String, Object?>();
      final requestedSenderId = effect['senderId'] as String?;
      if (requestedSenderId != null && requestedSenderId != actorId) {
        throw ArgumentError('程序消息只能以当前操作人身份发送');
      }
      final audience = (effect['audience'] as List?)?.cast<String>();
      if (audience != null &&
          (audience.isEmpty || audience.any((id) => !memberIds.contains(id)))) {
        throw ArgumentError('消息接收人必须是当前群成员');
      }
      final id = newMessageId();
      final definition = effect['card'] as Map?;
      // Follow-up cards retain the verified source card's author, not its respondent.
      // Ordinary messages still use the authenticated event actor.
      final senderId = definition != null && continuationSenderId != null
          ? continuationSenderId
          : requestedSenderId;
      if (definition == null && (effect['text'] as String).trim().isEmpty) {
        throw ArgumentError('小程序发送的消息不能为空');
      }
      final wakeAi = effect['wakeAi'] == true;
      if (wakeAi && audience == null) throw ArgumentError('触发 AI 回复需要明确接收人');
      final wakeMemberIds = (effect['wakeMemberIds'] as List?)?.cast<String>();
      if (wakeMemberIds != null &&
          wakeMemberIds.any(
            (id) => !agents.contains(id) || !(audience ?? []).contains(id),
          )) {
        throw ArgumentError('唤醒成员必须是消息可见范围内的 AI');
      }
      final card = definition == null
          ? null
          : InteractiveMessage.fromDefinition({
              ...definition.cast<String, Object?>(),
              'revision': 0,
              'showStatistics': definition['showStatistics'] ?? false,
              'buttons': [
                for (final button in definition['buttons'] as List)
                  {
                    ...(button as Map).cast<String, Object?>(),
                    'programEvent': effect['event'],
                  },
              ],
              'participation': {
                'visibility': 'private',
                'summaryVisibility': 'private',
                ...?definition['participation'] as Map?,
                if (audience != null) 'audience': audience,
                '_programMessage': messageId,
                if (wakeAi) '_programWake': true,
                if (wakeMemberIds != null) '_programWakeMembers': wakeMemberIds,
                if (senderId != null) '_creatorId': senderId,
              },
            });
      card?.validateTransport(html: false);
      if (card != null) {
        if (effect['event'] is! String || audience == null)
          throw ArgumentError('行动卡需要事件和明确的接收人');
        if (card.buttons.any((b) => b['notifyAi'] == true))
          throw ArgumentError('行动卡回调由小程序处理');
        if ((card.participation['callbackEvents'] as List?)?.isNotEmpty == true)
          throw ArgumentError('行动卡回调由小程序处理');
        final eligible = card.interaction['actors'] as List?;
        if (eligible != null && eligible.any((id) => !audience.contains(id)))
          throw ArgumentError('行动卡参与者必须在消息可见范围内');
        bindings[id] = {
          'key': effect['key'],
          'action': effect['event'],
          'data': effect['data'],
          'actors': card.interaction['actors'] ?? audience,
          if (effect['requirePublicMessage'] == true)
            'publicMessageSince': DateTime.now().microsecondsSinceEpoch,
        };
      }
      final metadata =
          card ??
          InteractiveMessage(
            revision: 0,
            title: effect['text'] as String,
            body: '',
            buttons: const [],
            participation: {
              'audience': audience,
              'presentation': 'message',
              '_programMessage': messageId,
              if (wakeAi) '_programWake': true,
              if (wakeMemberIds != null) '_programWakeMembers': wakeMemberIds,
            },
          );
      final message = AgentMessage(
        id: id,
        role: senderId != null && agents.contains(senderId)
            ? AgentMessageRole.assistant
            : AgentMessageRole.user,
        senderId: senderId ?? MessageSender.localUser.id,
        sender: senderId == null ? MessageSender.localUser : senders[senderId]!,
        text: effect['text'] as String? ?? card!.title,
        interactive: metadata,
        audience: audience,
        isSystem: card == null && senderId == null,
        isGroupMessage: true,
        markdown: effect['markdown'] == true,
        createdAt: DateTime.now(),
      );
      batch.insert('messages', messageRow(conversationId, message));
      created.add((message: message, wakeAi: wakeAi));
    }
    await batch.commit(noResult: true);
    if (effects.isNotEmpty) {
      final last = created.last.message;
      await txn.rawUpdate(
        'UPDATE conversations SET message_count = message_count + ?, preview = ?, updated_at = ? WHERE id = ?',
        [
          effects.length,
          last.canView(MessageSender.localUser.id) ? last.text : '私密交互消息',
          last.createdAt.microsecondsSinceEpoch,
          conversationId,
        ],
      );
    }
    return created;
  }
}
