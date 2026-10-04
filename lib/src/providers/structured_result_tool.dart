import 'dart:convert';
import '../domain/model_provider.dart';

/// A result-only tool; receiving its arguments grants no application authority.
class StructuredResultTool {
  const StructuredResultTool(this.name, this.description, this.parameters);

  final String name, description;
  final Map<String, Object?> parameters;

  Map<String, Object?> get request => {
    'tools': [
      {
        'type': 'function',
        'name': name,
        'description': description,
        'parameters': parameters,
        'strict': false,
      },
    ],
    'tool_choice': {'type': 'function', 'name': name},
    'parallel_tool_calls': false,
  };

  Map<String, dynamic> read(Map<String, Object?> response) {
    if (response['status'] != 'completed') {
      throw ModelProviderException('结构化结果未完成', detail: jsonEncode(response));
    }
    final calls = (response['output'] as List)
        .cast<Map>()
        .where((item) => item['type'] == 'function_call')
        .toList();
    if (calls.length != 1 || calls.single['name'] != name) {
      throw ModelProviderException(
        '模型必须调用一次 $name 提交结果',
        detail: jsonEncode(response),
      );
    }
    final value = jsonDecode(calls.single['arguments'] as String);
    if (value is! Map<String, dynamic>) {
      throw FormatException('工具参数必须是对象', calls.single['arguments']);
    }
    return value;
  }
}
