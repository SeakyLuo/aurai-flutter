/// Message-local, serializable functions: arguments in, ordinary DSL out.
/// Source definitions stay in the message; only the resolved view is expanded.
Map<String, Object?> expandInteractiveComponents(Map<String, Object?> source) {
  if (!source.containsKey('components')) return source;
  return _ComponentExpansion(source).expand();
}

class _ComponentExpansion {
  _ComponentExpansion(this.source);
  final Map<String, Object?> source;
  late final Map<String, Object?> definitions;
  var work = 0;

  Map<String, Object?> expand() {
    final raw = source['components'];
    if (raw is! Map || raw.length > 32) {
      throw ArgumentError('components 使用最多 32 个具名组件定义');
    }
    definitions = Map<String, Object?>.from(raw);
    for (final entry in definitions.entries) {
      if (!RegExp(r'^[A-Za-z][A-Za-z0-9_]{0,63}$').hasMatch(entry.key)) {
        throw ArgumentError('组件名使用 1–64 位英文字母、数字或下划线，以字母开头');
      }
      final definition = entry.value;
      if (definition is! Map ||
          definition.keys.any((key) => !['params', 'body'].contains(key)) ||
          definition['params'] is! Map ||
          definition['body'] is! Map) {
        throw ArgumentError('组件定义需要 params 参数声明和 body 组件树');
      }
      final params = definition['params'] as Map;
      if (params.length > 32) throw ArgumentError('组件最多 32 个参数');
      for (final param in params.entries) {
        final spec = param.value;
        if (param.key is! String ||
            (param.key as String).isEmpty ||
            spec is! Map ||
            spec.keys.any((key) => !['type', 'default'].contains(key)) ||
            ![
              'string',
              'number',
              'boolean',
              'object',
              'array',
              'widget',
            ].contains(spec['type'])) {
          throw ArgumentError('参数需要 type，可选 default');
        }
        if (spec.containsKey('default')) {
          _checkValue(param.key as String, spec['type'], spec['default']);
        }
      }
    }
    final root = Map<String, Object?>.of(source)..remove('components');
    return Map<String, Object?>.from(
      _resolve(root, const {}, const [], 0) as Map,
    );
  }

  Object? _resolve(
    Object? value,
    Map<String, Object?> args,
    List<String> stack,
    int depth,
  ) {
    if (++work > 10000 || depth > 64) {
      throw ArgumentError('组件展开超过 10000 步或 64 层');
    }
    if (value is List) {
      return [for (final item in value) _resolve(item, args, stack, depth + 1)];
    }
    if (value is! Map) return value;
    if (value.containsKey('param')) {
      final name = value['param'];
      if (value.length != 1 || name is! String || !args.containsKey(name)) {
        throw ArgumentError('参数引用必须为 {param: 已声明的参数名}');
      }
      return args[name];
    }
    if (value.containsKey('components')) {
      throw ArgumentError('components 只能声明在 content 根节点');
    }
    if (value['type'] == 'Component') {
      if (value.keys.any((key) => !['type', 'name', 'args'].contains(key))) {
        throw ArgumentError('Component 使用 name 和 args；key 通过参数传给实际组件');
      }
      final name = value['name'];
      if (name is! String || !definitions.containsKey(name)) {
        throw ArgumentError('未定义的组件 $name');
      }
      if (stack.contains(name))
        throw ArgumentError('组件不能递归调用：${[...stack, name].join(' → ')}');
      final definition = definitions[name] as Map;
      final params = definition['params'] as Map;
      final supplied = value['args'];
      if (supplied is! Map ||
          supplied.keys.any((key) => !params.containsKey(key))) {
        throw ArgumentError('$name.args 必须是已声明参数的对象');
      }
      final bound = <String, Object?>{};
      for (final entry in params.entries) {
        final spec = entry.value as Map;
        if (!supplied.containsKey(entry.key) && !spec.containsKey('default')) {
          throw ArgumentError('$name 缺少参数 ${entry.key}');
        }
        final argument = supplied.containsKey(entry.key)
            ? _resolve(supplied[entry.key], args, stack, depth + 1)
            : _resolve(spec['default'], const {}, stack, depth + 1);
        _checkValue(entry.key as String, spec['type'], argument);
        bound[entry.key as String] = argument;
      }
      return _resolve(definition['body'], bound, [...stack, name], depth + 1);
    }
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key as String: _resolve(entry.value, args, stack, depth + 1),
    };
  }

  void _checkValue(String name, Object? type, Object? value) {
    final valid = switch (type) {
      'string' => value is String,
      'number' => value is num && value.isFinite,
      'boolean' => value is bool,
      'object' => value is Map,
      'array' => value is List,
      'widget' => value is Map && value['type'] is String,
      _ => false,
    };
    if (!valid) throw ArgumentError('组件参数 $name 必须为 $type');
  }
}
