import 'package:sqflite/sqflite.dart';
import '../domain/agent_models.dart';
import '../domain/interactive_message.dart';
import '../domain/interactive_selection.dart';
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
  required InteractiveMessage resultCard,
  required Map<String, Object?> button,
}) async {
  final answers = button['questions'] != null
      ? button['value'] as List
      : [
          {
            'question': card.title,
            'answer': selectionEntries(button)
                .map(
                  (entry) => entry['text'] == null
                      ? entry['label'] as String
                      : '${entry['label']}：${entry['text']}',
                )
                .join('、'),
          },
        ];
  final conversation = (await db.query(
    'conversations',
    columns: ['kind'],
    where: 'id = ?',
    whereArgs: [conversationId],
    limit: 1,
  )).single;
  final members = await db.query(
    'conversation_members',
    columns: ['sender_id'],
    where: 'conversation_id = ? AND left_at IS NULL',
    whereArgs: [conversationId],
  );
  // A reply is a new message: freeze its audience to those allowed to read
  // this answer now, rather than inheriting the broader question audience.
  final audience = [
    for (final member in members)
      if (member['sender_id'] case final String viewer)
        if (card.canView(viewer) &&
            resultCard.canView(viewer) &&
            (viewer == actor.id ||
                resultCard.visible('visibility', actor: viewer)))
          viewer,
  ];
  final quote = MessageQuote(
    messageId: messageId,
    senderId: creatorId,
    text: answers.map((a) => a['question']).join('\n'),
    markdown: false,
    audience: audience,
    excludedAudience: (card.participation['excludedAudience'] as List?)
        ?.cast<String>(),
  )..resolveCard(card);
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
    role: actor.kind == MessageSenderKind.user
        ? AgentMessageRole.user
        : AgentMessageRole.assistant,
    senderId: actor.id,
    sender: actor,
    text: text,
    quote: quote,
    isGroupMessage: conversation['kind'] == 'group',
    createdAt: DateTime.now(),
    interactive: InteractiveMessage.card(
      revision: 0,
      title: text,
      body: '',
      buttons: const [],
      participation: {
        'presentation': 'message',
        'audience': audience,
        if (quote.excludedAudience != null)
          'excludedAudience': quote.excludedAudience,
      },
    ),
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
