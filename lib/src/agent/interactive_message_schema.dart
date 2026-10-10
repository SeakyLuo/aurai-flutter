import '../domain/interactive_button_icons.dart';
import 'question_batch_schema.dart';
import 'selection_option_schema.dart';

const interactiveSelectionSchema = {
  'type': 'object',
  'description':
      'Native fixed-option selection for polls and questions. Requires action:submit and a shared interaction. Multiple uses checkboxes and submits all selected options together after confirmation; text-only single choice submits on selection unless showConfirm is true. Rich-content options always require explicit submission, for both questions and polls. The UI renders selection hints and counts automatically. Do not repeat these in the title, body, or accompanying message (e.g. 可多选, 最多选3项). Configure mode and minSelections/maxSelections instead. Cannot combine with input. Works for humans and AI.',
  'properties': {
    'optionPrefix': {
      'type': 'string',
      'enum': ['number', 'letter', 'dot'],
      'description':
          'Option leading marker: number (1, 2), letter (A through Z, then AA, AB), or dot (small bullet). Presentation only; submit the original option id.',
    },
    'showConfirm': {
      'type': 'boolean',
      'default': false,
      'description':
          'Single choice submits immediately by default. Set true for consequential choices that need confirmation. Multiple choice always submits the selected set together.',
    },
    'mode': {
      'type': 'string',
      'enum': ['single', 'multiple'],
    },
    'options': {
      'type': 'array',
      'minItems': 1,
      'maxItems': 100,
      'items': selectionOptionSchema,
    },
    'minSelections': {
      'type': 'integer',
      'minimum': 1,
      'description': 'Default 1; single must be 1.',
    },
    'maxSelections': {
      'type': 'integer',
      'minimum': 1,
      'description': 'Default all options for multiple, 1 for single.',
    },
    'other': {
      'type': 'object',
      'description':
          'Optional write-in choice appended as 其他. Omit to disable. Counts as one choice toward min/max. Submit selected option IDs normally; when selecting __other__, submit value:{options:single ID or multiple ID array,otherText:written text}. Results aggregate under 其他; text follows existing choice visibility.',
      'properties': {
        'maxLength': {
          'type': 'integer',
          'minimum': 1,
          'maximum': 500,
          'default': 50,
          'description': 'Maximum user-perceived characters; defaults to 50.',
        },
      },
      'additionalProperties': false,
    },
  },
  'required': ['mode', 'options'],
  'additionalProperties': false,
};

const interactiveButtonColumnsSchema = {
  'type': 'integer',
  'minimum': 1,
  'maximum': 2,
  'description':
      'Native card button columns: 1 is a vertical list (default), 2 is an equal-width grid in row-major order. Use 2 for short voting/quiz options and 1 for long action labels. Odd final buttons stay half-width. This changes presentation only; tapping still executes immediately. Omitted updates/states/callbacks retain the current layout.',
};

const interactiveStatisticsSchema = {
  'type': 'boolean',
  'description':
      'Show the card View details statistics entry. Defaults to true. The entry is hidden while the viewer can submit or change a selection, and appears after submission or closing when statistics are visible. Set false to hide it during an activity, and set true in a final named state to reveal it locally on nextState. A state that omits this field inherits the current value. Updates may change this flag. This controls the entry only, not collection or participation visibility.',
};

const interactiveBodySchema = {
  'type': 'string',
  'maxLength': 10000,
  'description':
      'Keep card copy concise: include only information needed to decide and essential constraints. Do not repeat the title, options, button actions, or submission instructions. Selection mode and min/max counts are rendered by the UI; do not restate them in the title, body, or accompanying message. Omit reminders such as choose a target, confirm submission, use the private card, or discussion does not count as a vote. An empty body is appropriate when the title and options suffice. '
      r'Plain text supporting line breaks and blank lines. In JSON encode a line break once as \n, not \\n: the decoded string must contain a real newline, not literal backslash-n text. Do not JSON-encode the body separately. Markdown and HTML are not rendered.',
};

const interactiveButtonsSchema = {
  'type': 'array',
  'minItems': 1,
  'maxItems': 12,
  'items': {
    'type': 'object',
    'properties': {
      'id': {'type': 'string', 'minLength': 1},
      'label': {
        'type': 'string',
        'minLength': 1,
        'maxLength': 80,
        'description':
            'Button text, also used before a selection is made. For selection submit actions, prefer 提交 unless the activity needs a custom action label. Do not use instructions such as 请选择后提交 as the label.',
      },
      'action': {
        'type': 'string',
        'enum': ['update', 'acknowledge', 'openUrl', 'submit', 'nextRound'],
      },
      'style': {
        'type': 'string',
        'enum': ['normal', 'primary', 'info', 'warning', 'danger', 'success'],
        'description':
            'Optional visual emphasis: success is green, danger red, primary purple gradient with white text, info a separate light purple background with purple text; default normal. Prefer at most one primary action. Styling does not grant permissions or change what a button does.',
      },
      'icon': {
        'type': 'string',
        'default': 'none',
        'enum': interactiveButtonIcons,
        'description':
            'Optional leading outline icon. Defaults to none: no icon and centered text. An explicit icon aligns the content to the start.',
      },
      'showArrow': {
        'type': 'boolean',
        'description': 'Optional trailing arrow. Defaults to false.',
      },
      'notifyAi': {
        'type': 'boolean',
        'default': false,
        'description':
            'Queue an AI callback for non-voting actions or HTML text/json input. Fixed-option votes use participation.callbackEvents instead. Only this button waits until the creator commits content with updateInteractiveMessage + callbackEventId. A later state-changing action expires the previous callback. Failures can retry the same event without repeating this action. Omit/false for local-only changes.',
      },
      'repeatable': {'type': 'boolean'},
      'selection': interactiveSelectionSchema,
      'questions': questionBatchSchema,
      'input': {
        'type': 'string',
        'enum': ['text', 'json'],
        'description':
            'This submit endpoint accepts text or JSON from HTML, or a JSON object of form field values from native widget trees. The host binds the authenticated participant.',
      },
      'value': {
        'description':
            'For submit: any JSON value to record for this participant in the current shared round. Defaults to button id.',
      },
      'disabled': {'type': 'boolean'},
      'completedLabel': {'type': 'string', 'maxLength': 80},
      'nextState': {
        'type': 'string',
        'description':
            'For update: switch to this named state, replacing title, body and all buttons. Mutually exclusive with nextBody.',
      },
      'nextBody': interactiveBodySchema,
      'url': {'type': 'string'},
    },
    'required': ['id', 'label', 'action', 'repeatable'],
    'additionalProperties': false,
  },
};

const interactiveParticipationSchema = {
  'type': 'object',
  'properties': {
    'kind': {
      'type': 'string',
      'enum': ['questionnaire'],
      'description':
          'Questionnaire metadata for the existing InteractionCard selection/questions presentation. Custom DSL trees render entirely from their own generic bindings, Visibility and ForEach, regardless of this metadata; they do not need kind. Shared actors/completion/reveal/allowChange remain host business rules.',
    },
    'anonymous': {
      'type': 'boolean',
      'description':
          'Anonymous native poll. Default false; immutable after sending. No viewer, including the creator or an AI, can read other participants identities, ballots, reasons, or histories. Each participant can still read their own choice and change it if allowed. Aggregate visibility and reveal timing remain controlled separately. Vote callbacks omit actor identity and individual submission. The UI labels the card 匿名投票; do not repeat this in title/body. Miniapp native vote cards are supported: their reducer receives actorId:null and aggregate data only, never the submitted value or reason. HTML input and non-voting actions are not anonymous polls.',
    },
    'showHistory': {
      'type': 'boolean',
      'description':
          'Enable card history paging and participant operation history in the UI. Questions addressed to one actor never show history. Defaults to false for votes and questionnaires, and true for other interactive messages. Does not delete recorded actions or change current results.',
    },
    'excludedAudience': {
      'type': 'array',
      'minItems': 1,
      'uniqueItems': true,
      'items': {'type': 'string'},
      'description': '不可见成员；其余群成员可见。不能与 audience 同时设置。',
    },
    'audience': {
      'type': 'array',
      'items': {'type': 'string'},
      'description':
          'Only these known participants may view the card. Omit for everyone. The voting creator retains access to the card and live aggregate statistics. Voting eligibility is separately interaction.actors.',
    },
    'visibilityActors': {
      'type': 'array',
      'items': {'type': 'string'},
      'description':
          'Only these viewers can read others answers/choices, subject to visibility and timing. Mutually exclusive with visibilityExcludedActors. Questionnaire creators always see all answers; every respondent can still read their own answer.',
    },
    'visibilityExcludedActors': {
      'type': 'array',
      'minItems': 1,
      'uniqueItems': true,
      'items': {'type': 'string'},
      'description':
          'These viewers cannot read others answers/choices; everyone else follows visibility and timing. Mutually exclusive with visibilityActors. Does not hide the card or own answer. Questionnaire creators always see all answers. For hidden signup choices, exclude players and publish a separate public system announcement after collection.',
    },
    'summaryVisibilityActors': {
      'type': 'array',
      'items': {'type': 'string'},
      'description':
          'Additional allowlist for totals/results for other viewers; the creator always sees live aggregates.',
    },
    'presentation': {
      'type': 'string',
      'enum': ['author', 'system'],
      'description':
          'system displays a system activity card without an AI avatar. Presentation only: it does not grant system authority or change the real author. Use notifyAi:false for program-settled cards.',
    },
    'visibilityTiming': {
      'type': 'string',
      'enum': ['immediate', 'onComplete'],
      'description':
          'Independent timing for individual choices. Omitted inherits interaction.reveal. Still restricted by visibility and visibilityActors.',
    },
    'summaryVisibilityTiming': {
      'type': 'string',
      'enum': ['immediate', 'onComplete'],
      'description':
          'Independent timing for totals/results. Omitted inherits interaction.reveal.',
    },
    'visibilityImmediateActors': {
      'type': 'array',
      'items': {'type': 'string'},
      'description':
          'These viewers may see individual choices before publication. Still requires card audience and result visibility scope; private remains hidden. Questionnaire creators separately retain full answer access. Poll creators, humans and administrators receive no extra individual-choice privileges.',
    },
    'summaryVisibilityImmediateActors': {
      'type': 'array',
      'items': {'type': 'string'},
      'description':
          'These viewers may see totals/results before publication, subject to card audience and summaryVisibilityActors; private remains hidden.',
    },
    'callbackEvents': {
      'type': 'array',
      'uniqueItems': true,
      'items': {
        'type': 'string',
        'enum': ['vote', 'complete', 'pause'],
      },
      'description':
          'Register creator AI listeners: vote receives each submission/change (source=interactionVote, operationType=submit|change); complete receives completion/manual closure once (source=interactionComplete, collectionEvent=completed, completionType=conditionMet|manualClose, completionConditionMet); pause receives questionnaire collecting-to-paused transitions (source=interactionPaused, collectionEvent=paused). Pausing preserves answers without revealing onComplete results. Registration takes effect immediately without an enable switch. Omit/empty means no listener. Events include revision, round, sessionVersion, phase, submittedCount, eligibleCount when actors are specified, summary, and individual choices/state only if permitted. Non-anonymous vote events include actorId/actorName and permitted submission. Anonymous events contain aggregates only, never participant identity, individual submission, choices, or runtime state. No result acknowledgment, participant waiting or system receipt. If both subscribed, the last vote emits vote then complete.',
    },
    'visibility': {
      'type': 'string',
      'enum': ['public', 'private', 'afterClose'],
      'description':
          'Questionnaires default to private: only the creator and each respondent for their own answer. Set public and an optional visibilityActors/visibilityExcludedActors scope to share answers. Other activities retain their existing default.',
    },
    'summaryVisibility': {
      'type': 'string',
      'enum': ['public', 'private', 'afterClose'],
    },
    'selectionMode': {
      'type': 'string',
      'enum': ['actions', 'singleChoice'],
    },
    'closed': {'type': 'boolean'},
  },
  'additionalProperties': false,
};
