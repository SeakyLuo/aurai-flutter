import 'package:sqflite/sqflite.dart';
import '../domain/interactive_message.dart';
import '../domain/interactive_host_projection.dart';
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
  final notifyPause =
      events.contains('pause') &&
      !previous.collectionPaused &&
      current.collectionPaused &&
      !current.completed;
  final notifyComplete =
      events.contains('complete') &&
      !previous.completed &&
      current.completed &&
      current.participation['_completionNotifiedRound'] != round;
  if (!notifyVote && !notifyComplete && !notifyPause) return current;
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
    if (current.widgetTree.json['type'] != 'InteractionCard')
      'host': interactiveHostProjection(current, creatorId),
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
  if (notifyPause) {
    await MessageCallbacks.enqueue(
      db,
      id: newMessageId(),
      messageId: messageId,
      conversationId: conversationId,
      senderId: creatorId,
      payload: {
        ...result,
        'source': 'interactionPaused',
        'collectionEvent': 'paused',
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
      'collectionEvent': 'completed',
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
