import 'dart:convert';

import '../domain/model_provider.dart';
import 'response_citations.dart';

Future<Map<String, Object?>> readResponsesStream(
  Stream<List<int>> bytes, {
  void Function(String text)? onTextChanged,
  void Function()? onProcessingStarted,
  void Function(int index)? onMessageStarted,
}) async {
  var processingReported = false;
  void inspectItem(Map item) {
    final type = item['type'];
    if (!processingReported &&
        ((type == 'message' && item['phase'] == 'commentary') ||
            const {
              'function_call',
              'web_search_call',
              'computer_call',
              'code_interpreter_call',
              'file_search_call',
              'mcp_call',
              'image_generation_call',
              'local_shell_call',
              'shell_call',
              'apply_patch_call',
            }.contains(type))) {
      processingReported = true;
      onProcessingStarted?.call();
    }
  }

  final data = <String>[];
  int? activeMessage;
  final parts = <(int, int), String>{};
  await for (final line
      in bytes
          .timeout(const Duration(seconds: 60))
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
    if (line.startsWith('data:')) {
      final value = line.substring(5);
      data.add(value.startsWith(' ') ? value.substring(1) : value);
      continue;
    }
    if (line.isNotEmpty || data.isEmpty) continue;
    final payload = data.join('\n');
    data.clear();
    if (payload == '[DONE]') break;
    final event = (jsonDecode(payload) as Map).cast<String, Object?>();
    switch (event['type']) {
      case 'response.output_item.added':
      case 'response.output_item.done':
        final item = event['item'] as Map;
        inspectItem(item);
        if (event['type'] == 'response.output_item.done' &&
            item['type'] == 'message') {
          final text = (item['content'] as List)
              .cast<Map>()
              .map(
                (part) => switch (part['type']) {
                  'output_text' => responseTextWithCitations(
                    part.cast<String, Object?>(),
                  ),
                  'refusal' => part['refusal'] as String,
                  _ => '',
                },
              )
              .join('\n');
          if (text.isNotEmpty) {
            activeMessage = event['output_index'] as int;
            onMessageStarted?.call(activeMessage);
            onTextChanged?.call(text);
          }
        }
      case 'response.output_text.delta':
      case 'response.refusal.delta':
        final key = (
          event['output_index']! as int,
          event['content_index']! as int,
        );
        parts[key] = '${parts[key] ?? ''}${event['delta']! as String}';
        if (activeMessage != key.$1) {
          activeMessage = key.$1;
          onMessageStarted?.call(key.$1);
        }
        onTextChanged?.call(
          parts.entries
              .where((e) => e.key.$1 == key.$1)
              .map((e) => e.value)
              .join('\n'),
        );
      case 'response.incomplete':
      case 'response.failed':
      case 'response.completed':
        final response = (event['response']! as Map).cast<String, Object?>();
        for (final item in response['output'] as List) {
          inspectItem(item as Map);
        }
        return response;
      case 'error':
        throw ModelProviderException('模型回复未完成，请重试', detail: payload);
    }
  }
  throw const ModelProviderException('模型连接中断，回复未完成，请重试');
}
