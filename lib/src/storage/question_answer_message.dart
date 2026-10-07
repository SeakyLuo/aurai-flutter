import 'package:sqflite/sqflite.dart';
import '../domain/agent_models.dart';
import '../domain/interactive_message.dart';
import '../domain/message_quote.dart';
import '../domain/message_sender.dart';
import 'conversation_rows.dart';

Future<AgentMessage> writeQuestionAnswerMessage(
  DatabaseExecutor db, {
  required String conversationId,
  required String messageId,
  required String creatorId,
  required MessageSender actor,
  required InteractiveMessage card,
  required List answers,
}) async {
  final conversation = (await db.query(
    'conversations',
    columns: ['kind'],
    where: 'id = ?',
    whereArgs: [conversationId],
    limit: 1,
  )).single;
  final quote = MessageQuote(
    messageId: messageId,
    senderId: creatorId,
    text: answers.map((a) => a['question']).join('\n'),
    markdown: false,
    audience: (card.participation['audience'] as List?)?.cast<String>(),
    excludedAudience: (card.participation['excludedAudience'] as List?)
        ?.cast<String>(),
  );
  final creator = (await db.query(
    'message_senders',
    columns: ['name'],
    where: 'id = ?',
    whereArgs: [creatorId],
    limit: 1,
  )).single;
  quote.senderName = creator['name'] as String;
  final text = answers.length == 1
      ? answers.single['answer'] as String
      : [
          for (final (i, answer) in answers.indexed)
            '${i + 1}. ${answer['question']}\n${answer['answer']}',
        ].join('\n\n');
  final message = AgentMessage(
    id: newMessageId(),
    role: AgentMessageRole.user,
    senderId: actor.id,
    sender: actor,
    text: text,
    quote: quote,
    isGroupMessage: conversation['kind'] == 'group',
    createdAt: DateTime.now(),
    interactive: card.hasRestrictedAudience
        ? InteractiveMessage(
            revision: 0,
            title: text,
            body: '',
            buttons: const [],
            participation: {
              'presentation': 'message',
              if (quote.audience != null) 'audience': quote.audience,
              if (quote.excludedAudience != null)
                'excludedAudience': quote.excludedAudience,
            },
          )
        : null,
  );
  await db.insert('messages', messageRow(conversationId, message));
  await db.rawUpdate(
    'UPDATE conversations SET message_count = message_count + 1, preview = ?, updated_at = ? WHERE id = ?',
    [
      message.canView(MessageSender.localUser.id) ? text : '私密消息',
      message.createdAt.microsecondsSinceEpoch,
      conversationId,
    ],
  );
  return message;
}
