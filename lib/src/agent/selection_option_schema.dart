const selectionOptionSchema = {
  'type': 'object',
  'properties': {
    'id': {'type': 'string', 'minLength': 1},
    'label': {
      'type': 'string',
      'maxLength': 240,
      'description':
          'Required for text-only options. Optional for content-only options.',
    },
    'content': {
      'type': 'object',
      'description':
          'Embed the content of an existing accessible message as a compact square carousel option. Supports images, video/audio/files, miniapps and other message components. Use a real messageId from sent or read messages; never invent IDs. The source retains its permissions and state; ensure intended respondents can access it. Different options may reference different message types. Only options support rich content; question descriptions remain plain text. Media options always require explicit submission, including single choice.',
      'properties': {
        'messageId': {'type': 'string', 'minLength': 1},
      },
      'required': ['messageId'],
      'additionalProperties': false,
    },
    'value': {
      'description': 'Value recorded when selected; defaults to option id.',
    },
  },
  'required': ['id'],
  'additionalProperties': false,
};
