const interactionExpressionSchema = {
  'description':
      'JSON expression: constants and literal objects/arrays; {ref:"state.score"} reads a path; {op:"eq",args:[...]} evaluates. Use {literal:...} for data containing ref/op keys. Operators: eq, ne, gt, gte, lt, lte, and, or, not, if(condition,yes,no), add, subtract, sum(array), length, values(object), get(objectOrArray,key), concat. map/filter args=[array,expression], with item and index bound for each element. if/and/or are lazy. No scripts or network calls.',
};

const sharedInteractionSchema = {
  'type': 'object',
  'description':
      'Generic shared round, not a game type. Each actor submits one JSON value; completion rules run atomically and once. Completion automatically closes the card unless a nextRound button is configured. For a fixed voter list, configure actors and a completion expression comparing submittedCount with that list length. Missing completion means keep collecting until the author closes. Definition changes preserve current session; roundInitial applies on the next round.',
  'properties': {
    'initial': {
      'type': 'object',
      'additionalProperties': true,
      'description':
          'Initial shared state, e.g. scores and a relation table. Kept between rounds.',
    },
    'roundInitial': {
      'type': 'object',
      'additionalProperties': true,
      'description':
          'Fields reset on each round, overlaid on shared state, e.g. result:null.',
    },
    'actors': {
      'type': 'array',
      'items': {'type': 'string'},
      'description':
          'Optional eligible actor IDs already known from conversation context. Omit for open participation; never ask users for IDs.',
    },
    'allowChange': {
      'type': 'boolean',
      'description':
          'Defaults true. False locks an actor submission until next round.',
    },
    'reveal': {
      'type': 'string',
      'enum': ['immediate', 'onComplete'],
      'description':
          'Default reveal timing. onComplete hides others choices, aggregates and runtime state until the round completes or closes. participation visibilityTiming/summaryVisibilityTiming and their ImmediateActors configure each part independently.',
    },
    'completion': interactionExpressionSchema,
    'onComplete': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'when': interactionExpressionSchema,
          'set': {
            'type': 'object',
            'additionalProperties': true,
            'description':
                'Shared state fields and their expression values. Rules run in order; later rules see earlier writes.',
          },
        },
        'required': ['set'],
        'additionalProperties': false,
      },
    },
    'views': {
      'type': 'array',
      'description':
          'Result components bound to the viewer-visible context. They do not control settlement. Context: round, phase(collecting/completed/closed), closed, completed, submitted, self, revealed (choices or summary available), summaryVisible. submittedCount/distribution require summary visibility; choices/submissions require individual visibility; state requires both because it can contain derived choices and counts. Each follows its own audience/timing. Never rely on a hidden field. Completion rules have full state, choices/submissions, submittedCount, round, phase, closed.',
      'items': {
        'type': 'object',
        'properties': {
          'type': {
            'type': 'string',
            'enum': ['text', 'metric', 'distribution'],
          },
          'when': interactionExpressionSchema,
          'value': interactionExpressionSchema,
          'label': {'type': 'string'},
          'unit': {
            'type': 'string',
            'description':
                'Distribution count suffix, e.g. 票 or 人. Distribution includes zero-count submit options.',
          },
        },
        'required': ['type'],
        'additionalProperties': false,
      },
    },
  },
  'additionalProperties': false,
};
