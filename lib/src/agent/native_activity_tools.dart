import '../domain/interactive_message.dart';
import 'interactive_message_schema.dart';
import 'question_batch_schema.dart';

const nativeActivityDescriptions = {
  'sendQuestion':
      'Ask one known participant 1–10 independent questions using the native answer UI. Use askUser for ordinary clarification with the current human. Supply recipientId from the roster and questions; no widget tree, buttons or DSL required. Returns immediately; the recipient submits all answers together and a completion callback notifies you. Continue only independent work until the answer arrives. Do not repeat the questions in prose or ask another person to answer for the recipient.',
  'sendPoll':
      'Create a native poll with title and selection options. The app supplies selection, submission, editing and statistics UI; do not build a widget tree. actors optionally restricts voting to known members; audience independently restricts viewing. Anonymous ballots hide identities and individual choices even from the author. allowChange defaults to true. completeAfter optionally closes after that many participants submit; otherwise the author closes it later. Do not repeat selection instructions already shown by the UI.',
  'sendQuestionnaire':
      'Create a native questionnaire with title and 1–10 independent questions. The app supplies answering, validation, submission and response UI; no widget tree or DSL required. actors restricts participation; audience/excludedAudience controls card visibility. The creator always reads all answers; respondents read their own. Other answers are private by default, independently of completion. To share, set visibility:public and optionally visibilityActors (only these viewers) or visibilityExcludedActors (everyone except these viewers). allowChange defaults to true. completeAfter closes after that many submissions, otherwise the author closes it later. Use setQuestionnairePaused to pause/resume collection without discarding answers or revealing results. Default callbacks are pause and complete, distinguished by collectionEvent:paused|completed. Do not repeat the questionnaire as prose.',
};

Map<String, Object?> nativeActivitySchema(String name) => {
  'type': 'object',
  'description':
      'Sends in the current conversation, or an accessible conversationId. Native presentation and message actions are supplied by the app. Use readInteractiveMessage for current results and updateInteractiveMessage to close an existing activity; never resend merely to refresh results.',
  'properties': {
    'conversationId': {
      'type': 'string',
      'description': 'Optional known destination; omit for the current chat.',
    },
    'title': {'type': 'string', 'minLength': 1, 'maxLength': 100},
    'body': interactiveBodySchema,
    if (name == 'sendQuestion')
      'recipientId': {
        'type': 'string',
        'minLength': 1,
        'description':
            'Known roster ID, or user:local for the human. Never ask the user to enter an ID.',
      }
    else ...{
      'actors': {
        'type': 'array',
        'minItems': 1,
        'uniqueItems': true,
        'items': {'type': 'string', 'minLength': 1},
        'description':
            'Known eligible members; omit to allow conversation members.',
      },
      'allowChange': {'type': 'boolean', 'default': true},
      'completeAfter': {
        'type': 'integer',
        'minimum': 1,
        'description':
            'Number of participant submissions that completes collection. Omit for manual closure.',
      },
    },
    if (name == 'sendPoll') ...{
      'selection': interactiveSelectionSchema,
      'anonymous': {'type': 'boolean', 'default': false},
    } else
      'questions': questionBatchSchema,
    for (final key in [
      'audience',
      'excludedAudience',
      'visibilityActors',
      'visibilityExcludedActors',
      'visibility',
      'summaryVisibility',
      'visibilityTiming',
      'summaryVisibilityTiming',
      'callbackEvents',
    ])
      key: (interactiveParticipationSchema['properties'] as Map)[key],
  },
  'required': [
    'title',
    if (name == 'sendQuestion') 'recipientId',
    if (name == 'sendPoll') 'selection' else 'questions',
  ],
  'additionalProperties': false,
};

/// Native business tools own their presentation; the storage/action transport
/// remains shared with existing cards so permissions and callbacks stay atomic.
Map<String, Object?> nativeActivityArguments(
  String name,
  Map<String, Object?> args,
) {
  final question = name == 'sendQuestion';
  final poll = name == 'sendPoll';
  final actors = question
      ? [args['recipientId'] as String]
      : args['actors'] as List?;
  final completeAfter = question ? 1 : args['completeAfter'] as int?;
  if (completeAfter != null &&
      (completeAfter < 1 || actors != null && completeAfter > actors.length)) {
    throw ArgumentError('完成所需人数必须为正数，且不能超过指定参与人数');
  }
  return {
    if (args.containsKey('conversationId'))
      'conversationId': args['conversationId'],
    ...InteractiveMessage.cardDefinition({
      'title': args['title'],
      'body': args['body'] ?? '',
      'buttons': [
        {
          'id': 'submit',
          'label': poll ? '提交投票' : '提交回答',
          'action': 'submit',
          'style': 'primary',
          'repeatable': false,
          if (poll)
            'selection': args['selection']
          else
            'questions': args['questions'],
        },
      ],
      'interaction': {
        if (actors != null) 'actors': actors,
        'allowChange': question ? false : args['allowChange'] ?? true,
        if (completeAfter != null)
          'completion': {
            'op': 'gte',
            'args': [
              {'ref': 'submittedCount'},
              completeAfter,
            ],
          },
        'views': [
          if (poll) {'type': 'distribution', 'unit': '票'},
        ],
      },
      'participation': {
        if (name == 'sendQuestionnaire') 'kind': 'questionnaire',
        if (poll) 'anonymous': args['anonymous'] ?? false,
        'visibility': name == 'sendQuestionnaire' ? 'private' : 'public',
        'summaryVisibility': 'public',
        'visibilityTiming': question ? 'onComplete' : 'immediate',
        'summaryVisibilityTiming': 'immediate',
        'showHistory': false,
        'callbackEvents': [
          'complete',
          if (name == 'sendQuestionnaire') 'pause',
        ],
        for (final key in [
          'audience',
          'excludedAudience',
          'visibilityActors',
          'visibilityExcludedActors',
          'visibility',
          'summaryVisibility',
          'visibilityTiming',
          'summaryVisibilityTiming',
          'callbackEvents',
        ])
          if (args.containsKey(key)) key: args[key],
      },
    }),
  };
}
