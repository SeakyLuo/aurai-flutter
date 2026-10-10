import 'dart:convert';

/// Completed historical reads retain references, not stale source/state payloads.
/// Current tool results and failed-run continuations keep their original data.
List<Map<String, Object?>> miniappProtocolHistory(
  List<Map<String, Object?>> items,
) {
  const payloadFields = {
    'readHtmlApp': {'html', 'state'},
    'readHtmlMessage': {'html', 'state'},
    'readHtmlProgram': {'state', 'actionCards'},
    'submitHtmlProgramEvent': {'state', 'actionCards'},
    'readHtmlData': {'data'},
  };
  final calls = {
    for (final item in items)
      if (item['type'] == 'function_call') item['call_id']: item['name'],
  };
  return [
    for (final item in items)
      if (item['type'] == 'function_call_output' &&
          payloadFields.containsKey(calls[item['call_id']]) &&
          item['output'] is String)
        _historicalOutput(item, payloadFields[calls[item['call_id']]]!)
      else
        item,
  ];
}

Map<String, Object?> _historicalOutput(
  Map<String, Object?> item,
  Set<String> payloadFields,
) {
  final envelope = jsonDecode(item['output'] as String) as Map;
  // Errors remain verbatim, including service details and recovery arguments.
  if (envelope['status'] != 'success') return item;
  final result = Map<String, Object?>.from(envelope['result'] as Map);
  final omitted = payloadFields.where(result.containsKey).toList();
  if (omitted.isEmpty) return item;
  for (final field in omitted) {
    result.remove(field);
  }
  result['historicalPayload'] = {
    'omittedFields': omitted,
    'note':
        '此为历史操作记录，源码与状态快照已省略。标识、版本和执行结果保留；'
        '继续操作前使用当前运行时快照或重新读取，不重放已完成操作。',
  };
  return {
    ...item,
    'output': jsonEncode({...envelope, 'result': result}),
  };
}
