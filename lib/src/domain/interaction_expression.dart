import 'dart:convert';

/// Pure JSON expressions used by shared interactions and their visible views.
Object? evaluateInteraction(Object? expression, Map<String, Object?> context) {
  Object? eval(Object? value) => evaluateInteraction(value, context);
  if (expression is List) return expression.map(eval).toList();
  if (expression is! Map) return expression;
  if (expression.containsKey('literal')) return expression['literal'];
  if (expression.containsKey('ref')) {
    Object? value = context;
    for (final key in (expression['ref'] as String).split('.')) {
      if (value == null) return null;
      value = value is List ? value[int.parse(key)] : (value as Map)[key];
    }
    return value;
  }
  if (!expression.containsKey('op')) {
    return {
      for (final entry in expression.entries)
        entry.key as String: eval(entry.value),
    };
  }
  final op = expression['op'] as String;
  final args = expression['args'] as List;
  if (op == 'if') return eval(args[eval(args[0]) == true ? 1 : 2]);
  if (op == 'and') return args.every((arg) => eval(arg) == true);
  if (op == 'or') return args.any((arg) => eval(arg) == true);
  if (op == 'map' || op == 'filter') {
    final values = eval(args[0]) as List;
    return [
      for (final (index, item) in values.indexed)
        if (op == 'map')
          evaluateInteraction(args[1], {
            ...context,
            'item': item,
            'index': index,
          })
        else if (evaluateInteraction(args[1], {
              ...context,
              'item': item,
              'index': index,
            }) ==
            true)
          item,
    ];
  }
  final values = args.map(eval).toList();
  return switch (op) {
    'eq' => jsonEncode(values[0]) == jsonEncode(values[1]),
    'ne' => jsonEncode(values[0]) != jsonEncode(values[1]),
    'gt' => (values[0] as num) > (values[1] as num),
    'gte' => (values[0] as num) >= (values[1] as num),
    'lt' => (values[0] as num) < (values[1] as num),
    'lte' => (values[0] as num) <= (values[1] as num),
    'not' => values[0] != true,
    'add' => values.cast<num>().fold<num>(0, (a, b) => a + b),
    'subtract' => (values[0] as num) - (values[1] as num),
    'sum' => (values[0] as List).cast<num>().fold<num>(0, (a, b) => a + b),
    'length' => switch (values[0]) {
      final List v => v.length,
      final Map v => v.length,
      final String v => v.length,
      _ => throw ArgumentError('length 需要列表、对象或文字'),
    },
    'values' => (values[0] as Map).values.toList(),
    'get' =>
      values[0] is List
          ? (values[0] as List)[values[1] as int]
          : (values[0] as Map)[values[1]],
    'concat' => values.map((value) => value?.toString() ?? '').join(),
    _ => throw ArgumentError('不支持的交互表达式：$op'),
  };
}
