import 'package:sqflite/sqflite.dart';
import '../domain/interactive_message.dart';
import '../domain/agent_models.dart';
import 'message_callbacks.dart';
import '../domain/question_reply_signals.dart';

/// Queue a round completion in the same transaction as the final submission.
/// Optional vote events precede the completion event, without participant locks.
Future<InteractiveMessage> enqueueInteractiveCompletion(
  DatabaseExecutor db, {
  required String conversationId,
  required String messageId,
  required String creatorId,
  required InteractiveMessage previous,
  required InteractiveMessage current,
  String? actorId,
  String? actorName,
}) async {
  if (QuestionReplySignals.isWaiting(messageId)) return current;
  final round = current.shared ? current.engine.round : 1;
  final events = current.participation['callbackEvents'] as List? ?? const [];
  final notifyVote = actorId != null && events.contains('vote');
  final notifyComplete =
      events.contains('complete') &&
      !previous.completed &&
      current.completed &&
      current.participation['_completionNotifiedRound'] != round;
  if (!notifyVote && !notifyComplete) return current;
  final choicesVisible = current.visible('visibility', actor: creatorId);
  final result = <String, Object?>{
    'title': current.title,
    if (current.anonymous) 'anonymous': true,
    'revision': current.revision,
    'round': round,
    'sessionVersion': current.sessionVersion,
    'phase': current.shared
        ? current.engine.phase
        : current.closed
        ? 'closed'
        : 'collecting',
    'submittedCount': current.choices.length,
    if (current.shared && current.interaction['actors'] != null)
      'eligibleCount': (current.interaction['actors'] as List).length,
    'summary': current.summary,
    if (choicesVisible)
      'choices': {
        for (final entry in current.choices.entries)
          entry.key: {
            'name': entry.value['name'],
            'buttonId': entry.value['buttonId'],
            'label': entry.value['label'],
            if (entry.value.containsKey('value')) 'value': entry.value['value'],
            if (entry.value.containsKey('selections'))
              'selections': entry.value['selections'],
          },
      },
    if (current.shared && choicesVisible) 'state': current.engine.state,
  };
  if (notifyVote) {
    final ownChoice =
        !current.anonymous && (actorId == creatorId || choicesVisible);
    final submission = current.choices[actorId];
    await MessageCallbacks.enqueue(
      db,
      id: newMessageId(),
      messageId: messageId,
      conversationId: conversationId,
      senderId: creatorId,
      payload: {
        ...result,
        'source': 'interactionVote',
        'operationType': submission == null
            ? 'withdraw'
            : previous.choices.containsKey(actorId)
            ? 'change'
            : 'submit',
        if (!current.anonymous) ...{'actorId': actorId, 'actorName': actorName},
        if (ownChoice && submission != null)
          'submission': {
            'buttonId': submission['buttonId'],
            'label': submission['label'],
            if (submission.containsKey('value')) 'value': submission['value'],
            if (submission.containsKey('selections'))
              'selections': submission['selections'],
          },
      },
    );
  }
  if (!notifyComplete) return current;
  await MessageCallbacks.enqueue(
    db,
    id: newMessageId(),
    messageId: messageId,
    conversationId: conversationId,
    senderId: creatorId,
    payload: {
      ...result,
      'source': 'interactionComplete',
      'completionType': current.shared && current.engine.phase == 'completed'
          ? 'conditionMet'
          : 'manualClose',
      'completionConditionMet':
          current.shared && current.engine.phase == 'completed',
    },
  );
  return InteractiveMessage.fromJson({
    ...current.toJson(includeParticipants: true),
    'participation': {
      ...current.participation,
      '_completionNotifiedRound': round,
    },
  });
}
