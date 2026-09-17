const interactiveSelectionSchema = {
  'type': 'object',
  'description':
      'Native fixed-option selection followed by one explicit submit. Requires action:submit and a shared interaction. Single uses radio circles; multiple uses checkboxes. Options are not submitted until the confirmation button is pressed. Cannot combine with input. Works for humans and AI.',
  'properties': {
    'mode': {
      'type': 'string',
      'enum': ['single', 'multiple'],
    },
    'options': {
      'type': 'array',
      'minItems': 1,
      'maxItems': 24,
      'items': {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'minLength': 1},
          'label': {'type': 'string', 'minLength': 1},
          'value': {
            'description':
                'JSON value saved when selected; defaults to option id.',
          },
        },
        'required': ['id', 'label'],
        'additionalProperties': false,
      },
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
  },
  'required': ['mode', 'options'],
  'additionalProperties': false,
};

const interactiveButtonColumnsSchema = {
  'type': 'integer',
  'enum': [1, 2],
  'description':
      'Native card button columns: 1 is a vertical list (default), 2 is an equal-width grid in row-major order. Use 2 for short voting/quiz options and 1 for long action labels. Odd final buttons stay half-width. This changes presentation only; tapping still executes immediately. Omitted updates/states/callbacks retain the current layout.',
};

const interactiveStatisticsSchema = {
  'type': 'boolean',
  'description':
      'Show the View statistics message-menu entry. Defaults to true. Set false to hide it during an activity, and set true in a final named state to reveal it locally on nextState. A state that omits this field inherits the current value. Updates may change this flag. This controls the entry only, not collection or participation visibility.',
};

const interactiveBodySchema = {
  'type': 'string',
  'maxLength': 10000,
  'description':
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
      'label': {'type': 'string', 'minLength': 1, 'maxLength': 80},
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
        'enum': [
          'none',
          'info',
          'play',
          'reset',
          'delete',
          'check',
          'open',
          'settings',
        ],
        'description':
            'Optional leading outline icon. Omit to choose from action; none hides it.',
      },
      'showArrow': {
        'type': 'boolean',
        'description': 'Optional trailing arrow. Defaults to false.',
      },
      'notifyAi': {
        'type': 'boolean',
        'default': false,
        'description':
            'Queue an AI callback after this action. Only this button waits until the creator commits title/body/buttons with updateInteractiveMessage + callbackEventId. A later state-changing action expires the previous callback. Failures can retry the same event without repeating this action. Omit/false for local-only changes.',
      },
      'repeatable': {'type': 'boolean'},
      'selection': interactiveSelectionSchema,
      'input': {
        'type': 'string',
        'enum': ['text', 'json'],
        'description':
            'HTML messages only: this submit endpoint accepts page-provided text or JSON, max 16 KB. Native cards use fixed button values instead. The host binds the authenticated participant.',
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
    'audience': {
      'type': 'array',
      'items': {'type': 'string'},
      'description':
          'Only these known participants may view the card. Omit for everyone. Include the creator if they must read/administer it. Voting eligibility is separately interaction.actors.',
    },
    'visibilityActors': {
      'type': 'array',
      'items': {'type': 'string'},
      'description':
          'Additional allowlist for other participants choices; still follows visibility and reveal timing.',
    },
    'summaryVisibilityActors': {
      'type': 'array',
      'items': {'type': 'string'},
      'description':
          'Additional allowlist for totals/results; still follows summaryVisibility and reveal timing.',
    },
    'presentation': {
      'type': 'string',
      'enum': ['author', 'system'],
      'description':
          'system displays a system activity card without an AI avatar. Presentation only: it does not grant system authority or change the real author. Use notifyAi:false for program-settled cards.',
    },
    'visibility': {
      'type': 'string',
      'enum': ['public', 'private', 'afterClose'],
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
