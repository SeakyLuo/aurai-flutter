import 'interaction_expression.dart';

/// Expressions only see the supplied presentation context, never the card,
/// database or executor. UI visibility is not an authorization boundary.
void validateInteractiveBinding(
  Object? value, {
  required Set<String> fields,
  required Set<String> locals,
  bool inLoop = false,
  int depth = 0,
}) {
  if (depth > 16) throw ArgumentError('绑定表达式最多 16 层');
  if (value == null || value is bool || value is String || value is num) return;
  if (value is List) {
    if (value.length > 200) throw ArgumentError('绑定列表最多 200 项');
    for (final item in value) {
      validateInteractiveBinding(
        item,
        fields: fields,
        locals: locals,
        inLoop: inLoop,
        depth: depth + 1,
      );
    }
    return;
  }
  if (value is! Map) throw ArgumentError('绑定使用常量、ref 或 op/args');
  if (value.length == 1 && value['ref'] is String) {
    final parts = (value['ref'] as String).split('.');
    if (parts.any((part) => part.isEmpty) ||
        ![
          'host',
          'form',
          'display',
          'local',
          'item',
          'index',
          'time',
          'notifications',
        ].contains(parts.first)) {
      throw ArgumentError('绑定只能引用 host、form、display、local、item、index');
    }
    if (['form', 'display', 'local'].contains(parts.first) &&
        (parts.length != 2 ||
            !(parts.first == 'local' ? locals : fields).contains(parts[1]))) {
      throw ArgumentError('绑定引用了未定义的字段或本地状态');
    }
    if (['item', 'index'].contains(parts.first) && !inLoop) {
      throw ArgumentError('item/index 只能在 ForEach.template 中引用');
    }
    if (parts.first == 'time' &&
        (parts.length != 2 || !['now', 'utcOffsetMinutes'].contains(parts[1])))
      throw ArgumentError('时间绑定使用 time.now 或 time.utcOffsetMinutes');
    return;
  }
  const arities = <String, (int, int)>{
    'eq': (2, 2),
    'ne': (2, 2),
    'gt': (2, 2),
    'gte': (2, 2),
    'lt': (2, 2),
    'lte': (2, 2),
    'not': (1, 1),
    'and': (1, 32),
    'or': (1, 32),
    'if': (3, 3),
    'add': (2, 32),
    'subtract': (2, 2),
    'length': (1, 1),
    'concat': (1, 32),
    'get': (2, 2),
    'multiply': (2, 2),
    'divide': (2, 2),
    'modulo': (2, 2),
    'min': (2, 2),
    'max': (2, 2),
    'floor': (1, 1),
    'ceil': (1, 1),
    'round': (1, 1),
    'formatDuration': (2, 2),
    'formatDateTime': (2, 3),
    'nextTimeOfDay': (3, 4),
    'append': (2, 2),
    'slice': (3, 3),
  };
  final args = value['args'];
  final arity = arities[value['op']];
  if (value.length != 2 ||
      arity == null ||
      args is! List ||
      args.length < arity.$1 ||
      args.length > arity.$2) {
    throw ArgumentError('不支持的绑定表达式或参数数量');
  }
  for (final arg in args) {
    validateInteractiveBinding(
      arg,
      fields: fields,
      locals: locals,
      inLoop: inLoop,
      depth: depth + 1,
    );
  }
}

Object? resolveInteractiveBinding(
  Object? value,
  Map<String, Object?> context,
) => evaluateInteraction(value, context);
