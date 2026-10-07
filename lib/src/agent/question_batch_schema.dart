const questionBatchSchema = {
  'type': 'array',
  'minItems': 1,
  'maxItems': 10,
  'description':
      'One group of independent questions, normally 3–5 and at most 10. Each question is paged in the same card; all answers are submitted together. Do not batch a question that depends on a previous answer. IDs are internal and never shown to the user.',
  'items': {
    'type': 'object',
    'properties': {
      'id': {'type': 'string', 'minLength': 1},
      'question': {'type': 'string', 'minLength': 1, 'maxLength': 600},
      'description': {'type': 'string', 'maxLength': 1000},
      'mode': {
        'type': 'string',
        'enum': ['single', 'multiple', 'text'],
      },
      'required': {
        'type': 'boolean',
        'description': 'Default true. False permits explicit skipping.',
      },
      'allowCustomAnswer': {
        'type': 'boolean',
        'description':
            'Permit a written answer instead of selecting options. Text questions always accept text.',
      },
      'showConfirm': {
        'type': 'boolean',
        'default': false,
        'description':
            'Set true to confirm a single answer before submission. Default false. Multiple-choice and multi-question groups still submit together.',
      },
      'options': {
        'type': 'array',
        'maxItems': 25,
        'description':
            'Empty for text questions; at least one option for single/multiple. Do not repeat selection-mode instructions in question text.',
        'items': {
          'type': 'object',
          'properties': {
            'id': {'type': 'string', 'minLength': 1},
            'label': {'type': 'string', 'minLength': 1, 'maxLength': 240},
          },
          'required': ['id', 'label'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['id', 'question', 'mode', 'options'],
    'additionalProperties': false,
  },
};
