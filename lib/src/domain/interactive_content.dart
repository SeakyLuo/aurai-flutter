import 'package:characters/characters.dart';
import 'interactive_fields.dart';
import 'interactive_widget_catalog.dart';
import 'interactive_components.dart';
import 'interactive_bindings.dart';
import 'interactive_time.dart';
export 'interactive_fields.dart';

/// The serializable widget tree used by every interactive message presentation.
/// Action maps are interpreted by the existing interaction executor, never eval.
class InteractiveContent {
  InteractiveContent(Map<String, Object?> source)
    : json = expandInteractiveComponents(source);
  final Map<String, Object?> json;

  static const buttonTypes = {
    'InteractiveButton',
    'FilledButton',
    'TextButton',
  };
  static bool isMessageButton(Map<String, Object?> node) =>
      buttonTypes.contains(node['type']) &&
      (node['onPressed'] as Map).containsKey('action');

  static Map<String, Object?> button(Map<String, Object?> action) => {
    'type': 'InteractiveButton',
    'key': action['id'],
    'child': {'type': 'Text', 'data': action['label']},
    'onPressed': {...action}..remove('label'),
  };

  static Map<String, Object?> card({
    required String title,
    required String body,
    required List<Map<String, Object?>> buttons,
    int buttonColumns = 1,
    bool showStatistics = true,
  }) => {
    'type': 'InteractionCard',
    'title': {'type': 'Text', 'data': title},
    'child': {'type': 'Text', 'data': body},
    'children': buttons.map(button).toList(),
    'buttonColumns': buttonColumns,
    'showStatistics': showStatistics,
  };

  Iterable<Map<String, Object?>> get nodes => walk(json);

  static Iterable<Map<String, Object?>> walk(Map<String, Object?> node) sync* {
    yield node;
    if (node['title'] case final Map title) {
      yield* walk(Map<String, Object?>.from(title));
    }
    if (node['child'] case final Map child) {
      yield* walk(Map<String, Object?>.from(child));
    }
    if (node['template'] case final Map child) {
      yield* walk(Map<String, Object?>.from(child));
    }
    for (final child in node['children'] as List? ?? const []) {
      yield* walk(Map<String, Object?>.from(child as Map));
    }
    if ((node['onPressed'] as Map?)?['showBottomSheet'] case final Map sheet) {
      yield* walk(Map<String, Object?>.from(sheet['child'] as Map));
    }
  }

  List<Map<String, Object?>> get buttons => [
    for (final node in nodes)
      if (isMessageButton(node)) action(node),
  ];

  Map<String, Object?> get structure => transform(
    json,
    (node) => isMessageButton(node)
        ? {'type': node['type'], if (node['key'] != null) 'key': node['key']}
        : node,
  );

  Map<String, Object?> withTitle(String title) {
    var changed = false;
    return transform(json, (node) {
      if (!changed && node['type'] == 'Text' && node['data'] is String) {
        changed = true;
        return {...node, 'data': title};
      }
      return node;
    });
  }

  static Map<String, Object?> action(Map<String, Object?> node) => {
    ...Map<String, Object?>.from(node['onPressed'] as Map),
    'label': (node['child'] as Map)['data'],
  };

  String get title => json['type'] == 'InteractionCard'
      ? (json['title'] as Map)['data'] as String
      : nodes
                .where(
                  (node) => node['type'] == 'Text' && node['data'] is String,
                )
                .map((node) => node['data'] as String)
                .firstOrNull ??
            '';
  String get body => json['type'] == 'InteractionCard'
      ? (json['child'] as Map)['data'] as String
      : nodes
            .where((node) => node['type'] == 'Text' && node['data'] is String)
            .where(
              (node) =>
                  !buttons.any((button) => button['label'] == node['data']),
            )
            .skip(1)
            .map((node) => node['data'] as String)
            .join('\n');

  Map<String, Object?> withButtons(List<Map<String, Object?>> buttons) {
    final byId = {for (final button in buttons) button['id']: button};
    return transform(
      json,
      (node) => isMessageButton(node)
          ? {
              ...node,
              ...button(byId[(node['onPressed'] as Map)['id']]!),
              'type': node['type'],
              if (node['key'] != null) 'key': node['key'],
            }
          : node,
    );
  }

  Map<String, Object?> withBody(String body) {
    if (json['type'] != 'InteractionCard') {
      throw ArgumentError('nextBody 仅用于 InteractionCard；组件树切换使用 nextState');
    }
    return {
      ...json,
      'child': {'type': 'Text', 'data': body},
    };
  }

  static Map<String, Object?> transform(
    Map<String, Object?> node,
    Map<String, Object?> Function(Map<String, Object?>) change,
  ) => change({
    ...node,
    for (final slot in ['title', 'child', 'template'])
      if (node[slot] case final Map child)
        slot: transform(Map<String, Object?>.from(child), change),
    if (node['children'] case final List children)
      'children': [
        for (final child in children)
          transform(Map<String, Object?>.from(child as Map), change),
      ],
    if ((node['onPressed'] as Map?)?['showBottomSheet'] case final Map sheet)
      'onPressed': {
        'showBottomSheet': {
          ...sheet,
          'child': transform(
            Map<String, Object?>.from(sheet['child'] as Map),
            change,
          ),
        },
      },
  });

  Map<String, Object?> get initialValues => {
    for (final node in nodes)
      if (interactiveFieldTypes.contains(node['type']))
        node['key'] as String: interactiveInitialValue(node),
  };

  Map<String, Object?> resolveInput(Object? input) {
    if (input is! Map) throw ArgumentError('表单提交需要字段对象');
    final fields = nodes
        .where((node) => interactiveFieldTypes.contains(node['type']))
        .toList();
    final keys = fields.map((node) => node['key']).toSet();
    if (input.keys.any((key) => !keys.contains(key))) {
      throw ArgumentError('提交包含未定义的表单字段');
    }
    final values = <String, Object?>{};
    for (final field in fields) {
      final key = field['key'] as String;
      final value = input[key];
      if (!input.containsKey(key)) throw ArgumentError('提交缺少字段 $key');
      validateInteractiveFieldValue(field, value);
      values[key] = value;
    }
    return values;
  }

  void validate() {
    var count = 0;
    final keys = <String>{};
    final fields = nodes
        .where((node) => interactiveFieldTypes.contains(node['type']))
        .map((node) => node['key'] as String)
        .toSet();
    final initialState = json['state'] ?? const <String, Object?>{};
    if (initialState is! Map ||
        initialState.length > 32 ||
        initialState.entries.any(
          (entry) =>
              entry.key is! String ||
              (entry.key as String).isEmpty ||
              (entry.key as String).contains('.') ||
              !validInteractiveLocalValue(entry.value),
        )) {
      throw ArgumentError('state 使用最多 32 个具名文本、布尔值、有限数值或最多 200 项的简单列表');
    }
    if (json['runtime'] case final Object runtime) {
      if (runtime is! Map ||
          runtime.keys.any(
            (key) => !['persistState', 'refreshIntervalMs'].contains(key),
          ) ||
          runtime.containsKey('persistState') &&
              runtime['persistState'] is! bool)
        throw ArgumentError('runtime 使用 persistState 和 refreshIntervalMs');
      final interval = runtime['refreshIntervalMs'];
      if (interval != null &&
          (interval is! int || interval < 50 || interval > 60000))
        throw ArgumentError('refreshIntervalMs 需要 50–60000 毫秒');
    }
    final locals = initialState.keys.cast<String>().toSet();
    void binding(Object? value, {bool inLoop = false}) =>
        validateInteractiveBinding(
          value,
          fields: fields,
          locals: locals,
          inLoop: inLoop,
        );
    void visit(
      Map<String, Object?> node,
      int depth,
      String? parent, {
      bool inSheet = false,
      bool inLoop = false,
    }) {
      if (++count > 160 || depth > 16)
        throw ArgumentError('组件树最多 160 个节点、16 层');
      final type = node['type'];
      final allowed = switch (type) {
        'Column' || 'Row' => {
          'children',
          'spacing',
          'mainAxisAlignment',
          'crossAxisAlignment',
        },
        'Padding' => {'padding', 'child'},
        'SizedBox' => {'width', 'height', 'child'},
        'Expanded' => {'flex', 'child'},
        'Text' => {'data', 'style'},
        'TextField' => {'hintText', 'initialValue', 'maxLength', 'required'},
        'Visibility' => {'visible', 'child'},
        'ForEach' => {'items', 'template', 'offset', 'limit'},
        'LinearProgressIndicator' => {'value'},
        'InteractiveButton' ||
        'FilledButton' ||
        'TextButton' => {'child', 'onPressed'},
        'InteractionCard' => {
          'title',
          'child',
          'children',
          'buttonColumns',
          'showStatistics',
        },
        _ =>
          interactiveExtraProperties[type] ??
              (throw ArgumentError('不支持的组件 $type')),
      };
      if (node.keys.any(
        (key) =>
            key != 'type' &&
            key != 'key' &&
            !(['state', 'runtime'].contains(key) && depth == 0) &&
            !(key == 'enabled' &&
                (interactiveFieldTypes.contains(type) ||
                    buttonTypes.contains(type))) &&
            !(key == 'label' && interactiveFieldTypes.contains(type)) &&
            !allowed.contains(key),
      )) {
        throw ArgumentError('$type 包含未定义的参数');
      }
      if (inLoop &&
          (interactiveFieldTypes.contains(type) ||
              buttonTypes.contains(type))) {
        throw ArgumentError('动态 ForEach 用于展示结果；表单字段和动作请通过具名组件显式实例化');
      }
      if (node.containsKey('enabled')) binding(node['enabled'], inLoop: inLoop);
      if (type == 'Visibility') {
        if (!node.containsKey('visible') || node['child'] is! Map) {
          throw ArgumentError('Visibility 需要 visible 绑定和 child');
        }
        binding(node['visible'], inLoop: inLoop);
      }
      if (type == 'ForEach') {
        if (!node.containsKey('items') || node['template'] is! Map) {
          throw ArgumentError('ForEach 需要 items 列表绑定和 template');
        }
        binding(node['items'], inLoop: inLoop);
        binding(node['offset'] ?? 0, inLoop: inLoop);
        final limit = node['limit'] ?? 20;
        if (limit is! int || limit < 1 || limit > 50)
          throw ArgumentError('ForEach.limit 必须为 1–50');
      }
      if (type == 'LinearProgressIndicator')
        binding(node['value'], inLoop: inLoop);
      if (type == 'ProfileAvatar' && node['name'] is Map)
        binding(node['name'], inLoop: inLoop);
      if (node['key'] case final Object key) {
        if (key is! String || key.isEmpty || !keys.add(key))
          throw ArgumentError('组件 key 必须非空且唯一');
      }
      if (interactiveExtraProperties.containsKey(type))
        validateInteractiveExtra(node, parent);
      if (interactiveFieldTypes.contains(type)) validateInteractiveField(node);
      if (node['items'] case final List items) {
        count += items.length;
        if (count > 160) throw ArgumentError('组件与选项合计最多 160 个节点');
      }
      if (type == 'Text') {
        final data = node['data'];
        if ((data is Map || data is num || data is bool || data == null) &&
            parent != 'InteractionCard' &&
            !buttonTypes.contains(parent)) {
          binding(data, inLoop: inLoop);
        } else if (data is! String || data.length > 10000) {
          throw ArgumentError('Text.data 使用文本或绑定表达式');
        }
        if (node['style'] != null &&
            ![
              'titleMedium',
              'bodyMedium',
              'labelSmall',
              'displayMedium',
            ].contains(node['style']))
          throw ArgumentError('不支持的文字样式');
      }
      if (type == 'TextField') {
        if (node['key'] is! String) throw ArgumentError('TextField 需要稳定的 key');
        for (final name in ['hintText', 'initialValue']) {
          if (node[name] != null && node[name] is! String)
            throw ArgumentError('$name 必须为文本');
        }
        if (node['required'] != null && node['required'] is! bool)
          throw ArgumentError('required 必须为布尔值');
        final max = node['maxLength'] ?? 2000;
        if (max is! int || max < 1 || max > 10000)
          throw ArgumentError('maxLength 必须在 1–10000 之间');
        if (((node['initialValue'] ?? '') as String).characters.length > max)
          throw ArgumentError('初始文本超过 maxLength');
      }
      for (final name in ['width', 'height', 'spacing', 'padding']) {
        if (node[name] case final value?) {
          if (value is! num || !value.isFinite || value < 0 || value > 1000)
            throw ArgumentError('$name 必须为 0–1000 的有限数值');
        }
      }
      if (node['mainAxisAlignment'] != null &&
          ![
            'start',
            'end',
            'center',
            'spaceBetween',
            'spaceAround',
            'spaceEvenly',
          ].contains(node['mainAxisAlignment']))
        throw ArgumentError('不支持的主轴对齐方式');
      if (node['crossAxisAlignment'] != null &&
          ![
            'start',
            'end',
            'center',
            'stretch',
          ].contains(node['crossAxisAlignment']))
        throw ArgumentError('不支持的交叉轴对齐方式');
      if (type == 'Row' && node['crossAxisAlignment'] == 'stretch')
        throw ArgumentError('消息中的 Row 不支持无界高度拉伸');
      if (type == 'Expanded') {
        if (parent != 'Row') throw ArgumentError('Expanded 仅能直接放在 Row 中');
        final flex = node['flex'] ?? 1;
        if (flex is! int || flex < 1 || flex > 12)
          throw ArgumentError('flex 必须在 1–12 之间');
      }
      if (type == 'InteractionCard') {
        if (depth != 0) throw ArgumentError('InteractionCard 是独立的根组件');
        if ((node['title'] as Map?)?['type'] != 'Text' ||
            (node['child'] as Map?)?['type'] != 'Text')
          throw ArgumentError('InteractionCard 的 title 和 child 使用 Text');
        final title = (node['title'] as Map)['data'];
        if (title is! String || title.trim().isEmpty || title.length > 100) {
          throw ArgumentError('InteractionCard 标题需要 1–100 字');
        }
        if ((node['children'] as List).any(
          (child) => (child as Map)['type'] != 'InteractiveButton',
        ))
          throw ArgumentError('InteractionCard.children 使用 InteractiveButton');
        if (node['showStatistics'] != null && node['showStatistics'] is! bool)
          throw ArgumentError('showStatistics 必须为布尔值');
      }
      if (buttonTypes.contains(type) &&
          ((node['child'] as Map?)?['type'] != 'Text' ||
              node['onPressed'] is! Map))
        throw ArgumentError('$type 需要 Text child 和 onPressed 动作');
      if (buttonTypes.contains(type)) {
        final event = node['onPressed'] as Map;
        if (!event.containsKey('action')) {
          final label = (node['child'] as Map)['data'];
          if (label is! String || label.trim().isEmpty || label.length > 80) {
            throw ArgumentError('弹层按钮文字需为 1–80 字');
          }
          if (type == 'InteractiveButton') {
            throw ArgumentError(
              '现有 InteractiveButton 使用消息动作；本地弹层操作使用 FilledButton 或 TextButton',
            );
          }
          if (event['setState'] case final Map changes) {
            if (changes.isEmpty ||
                changes.keys.any((key) => !locals.contains(key)) ||
                event.keys.any(
                  (key) => ![
                    'setState',
                    'validateFields',
                    'scheduleNotification',
                    'cancelNotification',
                  ].contains(key),
                )) {
              throw ArgumentError('setState 只能更新已声明状态，可附带 validateFields');
            }
            for (final value in changes.values) {
              binding(value);
            }
            if (event['validateFields'] case final Object requested) {
              if (requested is! List ||
                  requested.any((key) => !fields.contains(key))) {
                throw ArgumentError('validateFields 使用已声明字段列表');
              }
            }
          } else if (event.length != 1) {
            throw ArgumentError('本地事件只能执行一个操作');
          } else if (event.containsKey('scheduleNotification') ||
              event.containsKey('cancelNotification') ||
              event['requestNotificationPermission'] == true) {
            // Host notifications are explicitly triggered actions, never build effects.
          } else if (event['showBottomSheet'] case final Map sheet) {
            if (inSheet) throw ArgumentError('暂不支持嵌套 bottomSheet');
            if (sheet.keys.any(
                  (key) => ![
                    'title',
                    'child',
                    'resizeToAvoidBottomInset',
                  ].contains(key),
                ) ||
                sheet['title'] is! String ||
                (sheet['title'] as String).trim().isEmpty ||
                (sheet['title'] as String).length > 100 ||
                sheet['child'] is! Map) {
              throw ArgumentError(
                'showBottomSheet 需要 1–100 字的 title 和 child 组件树',
              );
            }
            if (sheet.containsKey('resizeToAvoidBottomInset') &&
                sheet['resizeToAvoidBottomInset'] is! bool) {
              throw ArgumentError('resizeToAvoidBottomInset 必须是布尔值');
            }
            visit(
              Map<String, Object?>.from(sheet['child'] as Map),
              depth + 1,
              null,
              inSheet: true,
              inLoop: inLoop,
            );
          } else if (event['closeBottomSheet'] != true || !inSheet) {
            throw ArgumentError(
              '本地事件使用 showBottomSheet；closeBottomSheet:true 仅用于弹层内部',
            );
          }
          if (event.containsKey('scheduleNotification') &&
              event.containsKey('cancelNotification'))
            throw ArgumentError('一次操作不能同时设置和取消提醒');
          if (event.containsKey('scheduleNotification')) {
            final reminder = event['scheduleNotification'];
            if (reminder is! Map ||
                reminder.keys.any(
                  (key) =>
                      !['key', 'at', 'title', 'body', 'weekdays'].contains(key),
                ) ||
                reminder['key'] is! String ||
                (reminder['key'] as String).isEmpty ||
                !reminder.containsKey('at') ||
                !reminder.containsKey('title'))
              throw ArgumentError(
                'scheduleNotification 需要稳定 key、at 时间绑定和 title',
              );
            binding(reminder['at']);
            binding(reminder['title']);
            if (reminder.containsKey('body')) binding(reminder['body']);
            final days = reminder['weekdays'];
            if (days != null &&
                (days is! List ||
                    days.length > 7 ||
                    days.toSet().length != days.length ||
                    days.any((day) => day is! int || day < 1 || day > 7)))
              throw ArgumentError('weekdays 使用不重复的 1–7（周一到周日），省略为单次');
          }
          if (event.containsKey('cancelNotification') &&
              (event['cancelNotification'] is! String ||
                  (event['cancelNotification'] as String).isEmpty))
            throw ArgumentError('cancelNotification 使用提醒 key');
        } else if (event.containsKey('showBottomSheet') ||
            event.containsKey('setState') ||
            event.containsKey('scheduleNotification') ||
            event.containsKey('cancelNotification') ||
            event.containsKey('requestNotificationPermission') ||
            event.containsKey('closeBottomSheet')) {
          throw ArgumentError('消息动作不能混合本地弹层操作');
        }
      }
      if (['Padding', 'Expanded'].contains(type) && node['child'] is! Map)
        throw ArgumentError('$type 需要 child');
      if (type == 'Padding' && node['padding'] is! num)
        throw ArgumentError('Padding 需要数值 padding');
      if (['Row', 'Column', 'InteractionCard'].contains(type) &&
          node['children'] is! List)
        throw ArgumentError('$type 需要 children');
      for (final slot in ['title', 'child', 'template']) {
        if (node[slot] case final Map child)
          visit(
            Map<String, Object?>.from(child),
            depth + 1,
            type as String,
            inSheet: inSheet,
            inLoop: inLoop || type == 'ForEach',
          );
      }
      for (final child in node['children'] as List? ?? const []) {
        visit(
          Map<String, Object?>.from(child as Map),
          depth + 1,
          type as String,
          inSheet: inSheet,
          inLoop: inLoop,
        );
      }
    }

    visit(json, 0, null);
    if (initialValues.isNotEmpty &&
        !buttons.any((button) => button['input'] == 'json') &&
        !nodes.any(
          (node) =>
              (node['onPressed'] as Map?)?.containsKey('setState') == true ||
              (node['onPressed'] as Map?)?.containsKey(
                    'scheduleNotification',
                  ) ==
                  true,
        ))
      throw ArgumentError('表单需要 input:json 的提交动作');
    if (json['type'] != 'InteractionCard' &&
        buttons.any(
          (button) =>
              button['selection'] != null ||
              button['questions'] != null ||
              button['nextBody'] != null,
        )) {
      throw ArgumentError(
        'selection、questions 和 nextBody 使用 InteractionCard 复合组件',
      );
    }
  }
}
