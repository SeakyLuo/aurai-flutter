import '../domain/interactive_widget_catalog.dart';
import '../domain/avatar_portraits.dart';
import 'interactive_message_schema.dart';

const interactiveContentReference = {r'$ref': r'#/$defs/interactiveWidget'};
const interactiveBindingReference = {r'$ref': r'#/$defs/interactiveBinding'};
const interactiveBindingSchema = {
  'anyOf': [
    {
      'type': ['string', 'number', 'boolean', 'null'],
    },
    {
      'type': 'object',
      'properties': {
        'ref': {'type': 'string'},
      },
      'required': ['ref'],
      'additionalProperties': false,
    },
    {
      'type': 'object',
      'properties': {
        'op': {
          'type': 'string',
          'enum': [
            'eq',
            'ne',
            'gt',
            'gte',
            'lt',
            'lte',
            'not',
            'and',
            'or',
            'if',
            'add',
            'subtract',
            'length',
            'concat',
            'get',
          ],
        },
        'args': {
          'type': 'array',
          'maxItems': 32,
          'items': interactiveBindingReference,
        },
      },
      'required': ['op', 'args'],
      'additionalProperties': false,
    },
  ],
};

/// Recursive component schema shared by the definition and named states.
final interactiveContentSchema = {
  'type': 'object',
  'description':
      'A DSL designed around Flutter widgets and composition, rendered as native widgets. Column/Row use children; Padding/SizedBox/Expanded use child. '
      'Use Expanded for controls and long text in a Row. Expanded is only supported directly inside Row. '
      'InteractionCard is an existing compound root widget: '
      'title:Text, child:Text for description, children:InteractiveButton[]. '
      'It preserves the app selection, question, results and callback UI. '
      'General forms use Column, Text, TextField, ChoiceGroup and FilledButton/TextButton. '
      'For reusable AI-defined components, put components:{Name:{params:{label:{type:"string"},child:{type:"widget"}},body:WIDGET_TEMPLATE}} on the content root. '
      'Call with {type:"Component",name:"Name",args:{label:"Hello",child:{type:"Text",data:"World"}}}. '
      'Inside a template use {param:"label"} or {param:"child"} as a whole property value. Params may have default; all others are required. '
      'Templates may call other components; recursion is forbidden. Pass distinct field keys and action IDs explicitly when reusing components. Definitions are local to this content, including its sheets, and are preserved in the authored message. Each named state declares its own components. '
      'FilledButton/TextButton use child:Text and onPressed for a message action, local setState, {showBottomSheet:{title:"Title",child:WIDGET}}, or {closeBottomSheet:true} inside a sheet. Message actions require id/action/repeatable; local events do not use those properties and cannot be clicked through the AI tool. '
      'Sheets share the message form values and drafts; input:json submits ALL message fields, including sheet fields. Opening/closing a sheet does not submit. Sheets have a built-in close control; nested sheets are not supported. showBottomSheet.resizeToAvoidBottomInset defaults to false: the keyboard overlays the sheet without resizing it. Set true to resize the sheet above the keyboard. The covered chat stays stationary. '
      'ProfileAvatar reuses the app avatar renderer: name is required; icon is initial (default), app_logo_white or a registered portrait; size is 16–160 (default 40), color is a theme color. It supports component parameters and sheet content. '
      'Declare local state on content root as state:{step:0,editing:false}. Text.data, Visibility.visible, control enabled, ForEach.items/offset, LinearProgressIndicator.value and ProfileAvatar.name accept ref/op bindings. '
      'Use refs local.NAME, form.FIELD (raw in expressions), display.FIELD (formatted label), host.PROPERTY, item.PROPERTY and index inside ForEach. Text with a direct form ref retains formatted field display. '
      'A local onPressed:{setState:{step:{op:add,args:[{ref:local.step},1]}},validateFields:[FIELD]} validates selected fields before changing state. No submission occurs. Reset local state after confirmed participant updates. '
      'Visibility:{visible:BINDING,child:WIDGET} controls presentation only; all declared form fields still submit together. ForEach:{items:BINDING,template:WIDGET,offset:BINDING,limit:20} repeats read-only presentation; nested loops are supported. Use offset/limit with local paging controls for long results. Dynamic loop templates cannot contain fields/actions; instantiate form components with stable keys instead. Limit is 1–50; expanded UI budget is 640 nodes. '
      'host contains eligible,submitted,closed,completed,canSubmit,canEdit,summaryVisible,responsesVisible,submittedCount,eligibleCount,answers:[{question,answer}],responses:[{name,answers,label}],metrics:[{label,options:[{label,count,fraction}]}],distribution. Counts are null and lists empty when not permitted. Gate results with visibility flags. host.busy is available in UI. No private host state is exposed. '
      'Host shared interaction rules enforce actors, one submission per actor, allowChange, completion and result visibility independently of UI. Use callbackEvents for completion notifications. Local state and visibility cannot grant permission. Field label renders above the field and is captured with each answer; do not duplicate it as separate Text. '
      'Each form component key is the submitted field name and must stay stable across cosmetic edits; '
      'submit with onPressed.input:json sends all form fields as one object. '
      'Text.data may bind a field with {ref:"form.FIELD_KEY"}. '
      'SwitchListTile and CheckboxListTile require Text title and stable key. Slider uses min/max/divisions. DropdownButton and ChoiceGroup use items:[{value,child:Text}], with multiple/minSelections/maxSelections for ChoiceGroup. All fields submit together through input:json. Container uses theme color names. Stack needs a non-Positioned child to establish size. ListView is shrink-wrapped and scrolls with the conversation. '
      'This is the message definition itself, not an optional overlay. Maximum 160 nodes and depth 16.',
  'properties': {
    'type': {
      'type': 'string',
      'enum': [
        'Column',
        'Row',
        'Padding',
        'SizedBox',
        'Expanded',
        'Text',
        'TextField',
        'InteractiveButton',
        'FilledButton',
        'TextButton',
        'Component',
        'Visibility',
        'ForEach',
        'LinearProgressIndicator',
        'InteractionCard',
        ...interactiveExtraProperties.keys,
      ],
    },
    'key': {'type': 'string', 'minLength': 1},
    'state': {
      'type': 'object',
      'maxProperties': 32,
      'additionalProperties': {
        'type': ['string', 'boolean', 'number'],
      },
      'description':
          'Content root only. Local UI state, not shared interaction state.',
    },
    'visible': interactiveBindingReference,
    'enabled': interactiveBindingReference,
    'value': interactiveBindingReference,
    'offset': interactiveBindingReference,
    'limit': {'type': 'integer', 'minimum': 1, 'maximum': 50},
    'template': interactiveContentReference,
    'components': {
      'type': 'object',
      'maxProperties': 32,
      'description':
          'Content-root-only local function definitions. Bodies expand to ordinary DSL before validation/rendering; existing polls/questions are unchanged.',
      'additionalProperties': {
        'type': 'object',
        'properties': {
          'params': {
            'type': 'object',
            'maxProperties': 32,
            'additionalProperties': {
              'type': 'object',
              'properties': {
                'type': {
                  'type': 'string',
                  'enum': [
                    'string',
                    'number',
                    'boolean',
                    'object',
                    'array',
                    'widget',
                  ],
                },
                'default': <String, Object?>{},
              },
              'required': ['type'],
              'additionalProperties': false,
            },
          },
          'body': {
            'type': 'object',
            'description':
                'DSL template with whole-value {param:NAME} bindings, including child/children/action slots. The expanded tree must satisfy the widget schema.',
            'additionalProperties': true,
          },
        },
        'required': ['params', 'body'],
        'additionalProperties': false,
      },
    },
    'args': {'type': 'object', 'additionalProperties': true},
    'label': {
      'type': 'string',
      'minLength': 1,
      'maxLength': 600,
      'description':
          'Human-readable field label. Rendered above the field; captured with each answer for generic result lists.',
    },
    'icon': {
      'type': 'string',
      'enum': ['initial', 'app_logo_white', ...avatarPortraits.keys],
    },
    'children': {
      'type': 'array',
      'maxItems': 160,
      'items': interactiveContentReference,
    },
    'child': interactiveContentReference,
    'title': interactiveContentReference,
    'data': interactiveBindingReference,
    'style': {
      'type': 'string',
      'enum': ['titleMedium', 'bodyMedium', 'labelSmall'],
    },
    for (final name in [
      'padding',
      'width',
      'height',
      'spacing',
      'runSpacing',
      'borderRadius',
      'size',
      'thickness',
      'left',
      'top',
      'right',
      'bottom',
    ])
      name: {'type': 'number', 'minimum': 0, 'maximum': 1000},
    'flex': {'type': 'integer', 'minimum': 1, 'maximum': 12},
    'mainAxisAlignment': {
      'type': 'string',
      'enum': [
        'start',
        'end',
        'center',
        'spaceBetween',
        'spaceAround',
        'spaceEvenly',
      ],
    },
    'crossAxisAlignment': {
      'type': 'string',
      'enum': ['start', 'end', 'center', 'stretch'],
    },
    'hintText': {'type': 'string'},
    'initialValue': {
      'description':
          'Field initial value: string for TextField; boolean for toggles; number for Slider; option value or null for single choice; array of option values for multiple choice.',
    },
    'maxLength': {'type': 'integer', 'minimum': 1, 'maximum': 10000},
    'required': {'type': 'boolean'},
    'color': {'type': 'string', 'enum': interactiveThemeColors},
    'alignment': {
      'type': 'string',
      'enum': [
        ...interactiveAlignments,
        'start',
        'end',
        'spaceBetween',
        'spaceAround',
        'spaceEvenly',
      ],
    },
    'name': {
      'anyOf': [
        {'type': 'string'},
        interactiveBindingReference,
      ],
      'description':
          'Static component name; for ProfileAvatar a display name or binding; for Icon one of: ${interactiveIconNames.join(', ')}.',
    },
    'src': {'type': 'string', 'description': 'Image HTTPS URL.'},
    'semanticLabel': {'type': 'string'},
    'fit': {
      'type': 'string',
      'enum': [
        'contain',
        'cover',
        'fill',
        'fitWidth',
        'fitHeight',
        'none',
        'scaleDown',
      ],
    },
    'min': {'type': 'number'},
    'max': {'type': 'number'},
    'divisions': {'type': 'integer', 'minimum': 1, 'maximum': 1000},
    'multiple': {'type': 'boolean'},
    'minSelections': {'type': 'integer', 'minimum': 0},
    'maxSelections': {'type': 'integer', 'minimum': 1},
    'items': {
      'anyOf': [
        interactiveBindingReference,
        {
          'type': 'array',
          'minItems': 1,
          'maxItems': 100,
          'items': {
            'type': 'object',
            'properties': {
              'value': {'type': 'string', 'minLength': 1},
              'child': {
                'type': 'object',
                'properties': {
                  'type': {
                    'type': 'string',
                    'enum': ['Text'],
                  },
                  'data': {'type': 'string', 'minLength': 1},
                },
                'required': ['type', 'data'],
                'additionalProperties': false,
              },
            },
            'required': ['value', 'child'],
            'additionalProperties': false,
          },
        },
      ],
    },

    'showStatistics': interactiveStatisticsSchema,
    'buttonColumns': interactiveButtonColumnsSchema,
    'onPressed': {
      'anyOf': [
        {
          'type': 'object',
          'properties': {
            'setState': {
              'type': 'object',
              'minProperties': 1,
              'additionalProperties': interactiveBindingReference,
            },
            'validateFields': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
          'required': ['setState'],
          'additionalProperties': false,
        },
        {
          'type': 'object',
          'description':
              'Existing message action. Button label is child:Text.data. Selection/questions are rendered by the InteractionCard compound widget.',
          'properties': {
            for (final entry
                in ((interactiveButtonsSchema['items'] as Map)['properties']
                        as Map)
                    .entries)
              if (entry.key != 'label') entry.key: entry.value,
          },
          'required': ['id', 'action', 'repeatable'],
          'additionalProperties': false,
        },
        {
          'type': 'object',
          'properties': {
            'showBottomSheet': {
              'type': 'object',
              'properties': {
                'title': {'type': 'string', 'minLength': 1, 'maxLength': 100},
                'resizeToAvoidBottomInset': {
                  'type': 'boolean',
                  'default': false,
                  'description':
                      'Opt in to resizing the sheet above the keyboard. Default false keeps sheet geometry unchanged.',
                },
                'child': interactiveContentReference,
              },
              'required': ['title', 'child'],
              'additionalProperties': false,
            },
          },
          'required': ['showBottomSheet'],
          'additionalProperties': false,
        },
        {
          'type': 'object',
          'properties': {
            'closeBottomSheet': {'const': true},
          },
          'required': ['closeBottomSheet'],
          'additionalProperties': false,
        },
      ],
    },
  },
  'required': ['type'],
  'additionalProperties': false,
};
