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
            'Queue a callback to the creator after this user action. Omit/false for local-only changes.',
      },
      'repeatable': {'type': 'boolean'},
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
